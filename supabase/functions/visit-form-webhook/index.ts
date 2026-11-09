// Supabase Edge Function: visit-form-webhook
// Menerima jawaban Google Form via Apps Script trigger (On form submit),
// memvalidasi secara ketat, dan melakukan upsert idempoten ke public.visit_form_responses.

export const MAX_BODY_BYTES = 20 * 1024; // 20 KB

export interface ValidatedFormResponseRow {
  response_key: string;
  submitted_at?: string;
  responder_email: string;
  visit_date: string | null;
  sales_name: string;
  spv_name: string;
  tsc_name: string;
  customer_id: string;
  category: "rvai" | "dismantle" | "unpaid";
  visit_status: string;
  result: string;
  obstacles: string[];
  note: string;
  latitude: number | null;
  longitude: number | null;
  follow_up: string;
  follow_up_date: string | null;
  photo_urls: string[];
}

export interface ValidationResult {
  valid: boolean;
  invalidFields: string[];
  row?: ValidatedFormResponseRow;
}

export interface FormResponsesStore {
  upsertByResponseKey(row: ValidatedFormResponseRow): Promise<{ error?: { message: string } | null }>;
}

/**
 * Perbandingan string secara constant-time untuk mencegah timing attack pada x-webhook-secret.
 */
export function constantTimeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBytes = enc.encode(a);
  const bBytes = enc.encode(b);
  if (aBytes.length === 0 || bBytes.length === 0 || aBytes.length !== bBytes.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff === 0;
}

/**
 * Memetakan nilai kategori dari Form ('VISIT RVAI', 'DISMANTLE', 'UNPAID') atau nilai DB ('rvai', 'dismantle', 'unpaid').
 */
export function mapCategory(raw: unknown): "rvai" | "dismantle" | "unpaid" | null {
  if (typeof raw !== "string") return null;
  const cleaned = raw.trim().toUpperCase();
  switch (cleaned) {
    case "RVAI":
    case "VISIT RVAI":
      return "rvai";
    case "DISMANTLE":
      return "dismantle";
    case "UNPAID":
      return "unpaid";
    default:
      return null;
  }
}

/**
 * Validasi tanggal format YYYY-MM-DD. Mengembalikan null bila kosong, atau undefined bila format tidak valid.
 */
export function parseOptionalDate(raw: unknown): string | null | undefined {
  if (raw === null || raw === undefined || raw === "") return null;
  if (typeof raw !== "string") return undefined;
  const trimmed = raw.trim();
  if (trimmed === "") return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return undefined;
  const [y, m, d] = trimmed.split("-").map((n) => Number(n));
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (
    Number.isNaN(dt.getTime()) ||
    dt.getUTCFullYear() !== y ||
    dt.getUTCMonth() + 1 !== m ||
    dt.getUTCDate() !== d
  ) {
    return undefined;
  }
  return trimmed;
}

/**
 * Mem-parse koordinat dari objek payload (mendukung angka latitude/longitude terpisah atau string gabungan "lat, lng").
 * Mengembalikan { lat, lng, valid }.
 */
export function parseCoordinates(payload: Record<string, unknown>): {
  latitude: number | null;
  longitude: number | null;
  valid: boolean;
} {
  const rawCombined = payload.coordinates ?? payload.coordinate_string;
  const hasSeparateLat = payload.latitude !== undefined && payload.latitude !== null && payload.latitude !== "";
  const hasSeparateLng = payload.longitude !== undefined && payload.longitude !== null && payload.longitude !== "";

  if (!hasSeparateLat && !hasSeparateLng) {
    if (rawCombined === undefined || rawCombined === null || String(rawCombined).trim() === "") {
      return { latitude: null, longitude: null, valid: true };
    }
    const text = String(rawCombined).trim();
    const parts = text.split(",").map((p) => p.trim());
    if (parts.length !== 2) {
      return { latitude: null, longitude: null, valid: false };
    }
    const lat = Number(parts[0]);
    const lng = Number(parts[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0) {
      return { latitude: null, longitude: null, valid: false };
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return { latitude: null, longitude: null, valid: false };
    }
    return { latitude: lat, longitude: lng, valid: true };
  }

  // Jika hanya salah satu diisi namun bukan pasangan lengkap
  if (hasSeparateLat !== hasSeparateLng) {
    // Coba cek apakah payload.latitude berisi string "lat, lng"
    if (typeof payload.latitude === "string" && payload.latitude.includes(",") && !hasSeparateLng) {
      const parts = payload.latitude.split(",").map((p) => p.trim());
      if (parts.length === 2) {
        const lat = Number(parts[0]);
        const lng = Number(parts[1]);
        if (Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && lat !== 0 && lng !== 0) {
          return { latitude: lat, longitude: lng, valid: true };
        }
      }
    }
    return { latitude: null, longitude: null, valid: false };
  }

  const lat = Number(payload.latitude);
  const lng = Number(payload.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat === 0 || lng === 0) {
    return { latitude: null, longitude: null, valid: false };
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return { latitude: null, longitude: null, valid: false };
  }
  return { latitude: lat, longitude: lng, valid: true };
}

function validateOptionalText(raw: unknown, maxLen: number): string | undefined {
  if (raw === null || raw === undefined) return "";
  if (typeof raw !== "string") return undefined;
  const trimmed = raw.trim();
  if (trimmed.length > maxLen) return undefined;
  return trimmed;
}

/**
 * Validasi murni untuk payload JSON webhook Google Form.
 */
export function validateWebhookPayload(rawPayload: unknown): ValidationResult {
  if (!rawPayload || typeof rawPayload !== "object" || Array.isArray(rawPayload)) {
    return { valid: false, invalidFields: ["payload"] };
  }
  const p = rawPayload as Record<string, unknown>;
  const invalidFields: string[] = [];

  // 1. response_key (string 1..128)
  const responseKey = typeof p.response_key === "string" ? p.response_key.trim() : "";
  if (responseKey.length < 1 || responseKey.length > 128) {
    invalidFields.push("response_key");
  }

  // 2. customer_id (angka 6..12 digit)
  const customerId = typeof p.customer_id === "string" || typeof p.customer_id === "number"
    ? String(p.customer_id).trim()
    : "";
  if (!/^\d{6,12}$/.test(customerId)) {
    invalidFields.push("customer_id");
  }

  // 3. category
  const category = mapCategory(p.category);
  if (!category) {
    invalidFields.push("category");
  }

  // 4. responder_email (format email, lowercase, <= 254)
  const rawEmail = typeof p.responder_email === "string" ? p.responder_email.trim().toLowerCase() : "";
  if (
    rawEmail.length < 3 ||
    rawEmail.length > 254 ||
    !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(rawEmail)
  ) {
    invalidFields.push("responder_email");
  }

  // 5. Tanggal YYYY-MM-DD atau null
  const visitDate = parseOptionalDate(p.visit_date);
  if (visitDate === undefined) {
    invalidFields.push("visit_date");
  }

  const followUpDate = parseOptionalDate(p.follow_up_date);
  if (followUpDate === undefined) {
    invalidFields.push("follow_up_date");
  }

  // 6. submitted_at (opsional ISO string)
  let submittedAt: string | undefined = undefined;
  if (p.submitted_at !== undefined && p.submitted_at !== null && p.submitted_at !== "") {
    if (typeof p.submitted_at !== "string" || Number.isNaN(Date.parse(p.submitted_at))) {
      invalidFields.push("submitted_at");
    } else {
      submittedAt = new Date(p.submitted_at).toISOString();
    }
  }

  // 7. Panjang teks (note <= 4000, lainnya <= 300)
  const salesName = validateOptionalText(p.sales_name, 300);
  if (salesName === undefined) invalidFields.push("sales_name");

  const spvName = validateOptionalText(p.spv_name, 300);
  if (spvName === undefined) invalidFields.push("spv_name");

  const tscName = validateOptionalText(p.tsc_name, 300);
  if (tscName === undefined) invalidFields.push("tsc_name");

  const visitStatus = validateOptionalText(p.visit_status, 300);
  if (visitStatus === undefined) invalidFields.push("visit_status");

  const result = validateOptionalText(p.result, 300);
  if (result === undefined) invalidFields.push("result");

  const followUp = validateOptionalText(p.follow_up, 300);
  if (followUp === undefined) invalidFields.push("follow_up");

  const note = validateOptionalText(p.note, 4000);
  if (note === undefined) invalidFields.push("note");

  // 8. obstacles (array <= 20 item, masing-masing <= 300 karakter)
  const obstacles: string[] = [];
  if (p.obstacles !== undefined && p.obstacles !== null) {
    if (!Array.isArray(p.obstacles) || p.obstacles.length > 20) {
      invalidFields.push("obstacles");
    } else {
      for (const item of p.obstacles) {
        if (typeof item !== "string" || item.trim().length > 300) {
          invalidFields.push("obstacles");
          break;
        }
        if (item.trim().length > 0) {
          obstacles.push(item.trim());
        }
      }
    }
  }

  // 9. photo_urls (array <= 10 item, masing-masing wajib diawali https://drive.google.com/ dan <= 300 karakter)
  const photoUrls: string[] = [];
  if (p.photo_urls !== undefined && p.photo_urls !== null) {
    if (!Array.isArray(p.photo_urls) || p.photo_urls.length > 10) {
      invalidFields.push("photo_urls");
    } else {
      for (const url of p.photo_urls) {
        if (
          typeof url !== "string" ||
          url.trim().length > 300 ||
          !url.trim().startsWith("https://drive.google.com/")
        ) {
          invalidFields.push("photo_urls");
          break;
        }
        photoUrls.push(url.trim());
      }
    }
  }

  // 10. Koordinat
  const coords = parseCoordinates(p);
  if (!coords.valid) {
    invalidFields.push("coordinates");
  }

  if (invalidFields.length > 0 || !category || visitDate === undefined || followUpDate === undefined) {
    return { valid: false, invalidFields };
  }

  const row: ValidatedFormResponseRow = {
    response_key: responseKey,
    ...(submittedAt ? { submitted_at: submittedAt } : {}),
    responder_email: rawEmail,
    visit_date: visitDate,
    sales_name: salesName!,
    spv_name: spvName!,
    tsc_name: tscName!,
    customer_id: customerId,
    category,
    visit_status: visitStatus!,
    result: result!,
    obstacles,
    note: note!,
    latitude: coords.latitude,
    longitude: coords.longitude,
    follow_up: followUp!,
    follow_up_date: followUpDate,
    photo_urls: photoUrls,
  };

  return { valid: true, invalidFields: [], row };
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

/**
 * Handler utama HTTP untuk Edge Function (menerima dependensi yang dapat di-inject untuk unit test).
 */
export async function handleWebhookRequest(
  req: Request,
  options: {
    expectedSecret: string | undefined;
    store: FormResponsesStore;
    logger?: (msg: string) => void;
  },
): Promise<Response> {
  const log = options.logger ?? ((msg: string) => console.log(msg));

  // 1. Hanya POST
  if (req.method.toUpperCase() !== "POST") {
    return jsonResponse(405, { ok: false, error: "method_not_allowed" });
  }

  // 2. Periksa konfigurasi secret di server
  const expectedSecret = options.expectedSecret?.trim() ?? "";
  if (expectedSecret.length === 0) {
    log("webhook_result status=500 reason=missing_server_secret");
    return jsonResponse(500, { ok: false, error: "server_misconfigured" });
  }

  // 3. Autentikasi constant-time x-webhook-secret
  const providedSecret = req.headers.get("x-webhook-secret") ?? "";
  if (!constantTimeEqual(providedSecret, expectedSecret)) {
    log("webhook_result status=401");
    return jsonResponse(401, { ok: false, error: "unauthorized" });
  }

  // 4. Batas ukuran body <= 20 KB
  const contentLengthHeader = req.headers.get("content-length");
  if (contentLengthHeader !== null) {
    const contentLength = Number(contentLengthHeader);
    if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
      log("webhook_result status=413");
      return jsonResponse(413, { ok: false, error: "payload_too_large" });
    }
  }

  let rawBuffer: ArrayBuffer;
  try {
    rawBuffer = await req.arrayBuffer();
  } catch (_) {
    return jsonResponse(400, { ok: false, error: "invalid_body" });
  }

  if (rawBuffer.byteLength > MAX_BODY_BYTES) {
    log("webhook_result status=413");
    return jsonResponse(413, { ok: false, error: "payload_too_large" });
  }

  let parsedJson: unknown;
  try {
    const text = new TextDecoder().decode(rawBuffer);
    parsedJson = JSON.parse(text);
  } catch (_) {
    log("webhook_result status=400 reason=invalid_json");
    return jsonResponse(400, { ok: false, error: "invalid_json" });
  }

  // 5. Validasi payload
  const validation = validateWebhookPayload(parsedJson);
  if (!validation.valid || !validation.row) {
    const safeKey = typeof (parsedJson as Record<string, unknown>)?.response_key === "string"
      ? String((parsedJson as Record<string, unknown>).response_key).slice(0, 64)
      : "unknown";
    log(`webhook_result response_key=${safeKey} status=400`);
    return jsonResponse(400, {
      ok: false,
      error: "validation_failed",
      fields: validation.invalidFields,
    });
  }

  // 6. Upsert idempoten ke visit_form_responses
  try {
    const { error } = await options.store.upsertByResponseKey(validation.row);
    if (error) {
      log(`webhook_result response_key=${validation.row.response_key} status=500`);
      return jsonResponse(500, { ok: false, error: "database_error" });
    }
    log(`webhook_result response_key=${validation.row.response_key} status=200`);
    return jsonResponse(200, { ok: true });
  } catch (_) {
    log(`webhook_result response_key=${validation.row.response_key} status=500`);
    return jsonResponse(500, { ok: false, error: "internal_error" });
  }
}

// Entrypoint runtime Supabase Edge Functions (hanya dijalankan saat file ini dieksekusi sebagai main module)
if (import.meta.main) {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.45.4");

  Deno.serve(async (req: Request) => {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const webhookSecret = Deno.env.get("VISIT_FORM_WEBHOOK_SECRET");

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const store: FormResponsesStore = {
      async upsertByResponseKey(row: ValidatedFormResponseRow) {
        const { error } = await supabase
          .from("visit_form_responses")
          .upsert(row, { onConflict: "response_key" });
        return { error: error ? { message: error.message } : null };
      },
    };

    return await handleWebhookRequest(req, {
      expectedSecret: webhookSecret,
      store,
    });
  });
}
