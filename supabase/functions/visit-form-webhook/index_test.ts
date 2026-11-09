import {
  FormResponsesStore,
  handleWebhookRequest,
  MAX_BODY_BYTES,
  ValidatedFormResponseRow,
  validateWebhookPayload,
} from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, msg?: string): void {
  const a = JSON.stringify(actual);
  const b = JSON.stringify(expected);
  if (a !== b) {
    throw new Error(`${msg ?? "Assertion failed"}: expected ${b}, got ${a}`);
  }
}

function assertTrue(cond: boolean, msg?: string): void {
  if (!cond) {
    throw new Error(msg ?? "Expected true, got false");
  }
}

class FakeStore implements FormResponsesStore {
  public rows = new Map<string, ValidatedFormResponseRow>();

  async upsertByResponseKey(
    row: ValidatedFormResponseRow,
  ): Promise<{ error?: { message: string } | null }> {
    this.rows.set(row.response_key, row);
    return { error: null };
  }
}

const TEST_SECRET = "0123456789abcdef0123456789abcdef";

function buildValidPayload(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    response_key: "resp-001",
    submitted_at: "2026-11-09T03:00:00Z",
    responder_email: "Budi.Sales@Example.com",
    visit_date: "2026-11-09",
    sales_name: "BUDI SANTOSO",
    spv_name: "SPV HERI",
    tsc_name: "TSC PIPIN",
    customer_id: "32018899",
    category: "VISIT RVAI",
    visit_status: "Bertemu Pelanggan",
    result: "Lancar & Aktif",
    obstacles: ["Cuaca Hujan"],
    note: "Pelanggan puas dengan layanan",
    coordinates: "-7.712345, 109.012345",
    follow_up: "Tidak perlu",
    follow_up_date: null,
    photo_urls: ["https://drive.google.com/file/d/abc123XYZ/view"],
    ...overrides,
  };
}

Deno.test("405 Method Not Allowed untuk selain POST", async () => {
  const store = new FakeStore();
  const req = new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
    method: "GET",
  });
  const res = await handleWebhookRequest(req, { expectedSecret: TEST_SECRET, store });
  assertEquals(res.status, 405);
});

Deno.test("401 Unauthorized bila x-webhook-secret kosong atau salah", async () => {
  const store = new FakeStore();
  const reqNoHeader = new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
    method: "POST",
    body: JSON.stringify(buildValidPayload()),
  });
  const res1 = await handleWebhookRequest(reqNoHeader, { expectedSecret: TEST_SECRET, store });
  assertEquals(res1.status, 401);

  const reqWrongHeader = new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
    method: "POST",
    headers: { "x-webhook-secret": "wrong-secret" },
    body: JSON.stringify(buildValidPayload()),
  });
  const res2 = await handleWebhookRequest(reqWrongHeader, { expectedSecret: TEST_SECRET, store });
  assertEquals(res2.status, 401);
});

Deno.test("413 Payload Too Large bila body melebihi 20 KB", async () => {
  const store = new FakeStore();
  const hugeString = "A".repeat(MAX_BODY_BYTES + 100);
  const req = new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
    method: "POST",
    headers: { "x-webhook-secret": TEST_SECRET },
    body: hugeString,
  });
  const res = await handleWebhookRequest(req, { expectedSecret: TEST_SECRET, store });
  assertEquals(res.status, 413);
});

Deno.test("400 Bad Request untuk customer_id, kategori, email, dan photo_urls tidak valid", async () => {
  const store = new FakeStore();
  const badPayload = buildValidPayload({
    customer_id: "12AB", // bukan 6-12 digit angka
    category: "KATEGORI SALAH",
    responder_email: "bukan-email",
    photo_urls: ["https://evil.example.com/photo.jpg"], // bukan https://drive.google.com/
  });
  const req = new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
    method: "POST",
    headers: { "x-webhook-secret": TEST_SECRET },
    body: JSON.stringify(badPayload),
  });
  const res = await handleWebhookRequest(req, { expectedSecret: TEST_SECRET, store });
  assertEquals(res.status, 400);
  const body = await res.json();
  assertTrue(Array.isArray(body.fields), "fields harus berupa array");
  assertTrue(body.fields.includes("customer_id"), "customer_id harus ditandai salah");
  assertTrue(body.fields.includes("category"), "category harus ditandai salah");
  assertTrue(body.fields.includes("responder_email"), "responder_email harus ditandai salah");
  assertTrue(body.fields.includes("photo_urls"), "photo_urls harus ditandai salah");
});

Deno.test("Pemetaan label kategori Form dan parsing koordinat 'lat, lng'", () => {
  const vRvai = validateWebhookPayload(buildValidPayload({ category: "VISIT RVAI" }));
  assertTrue(vRvai.valid);
  assertEquals(vRvai.row?.category, "rvai");
  assertEquals(vRvai.row?.latitude, -7.712345);
  assertEquals(vRvai.row?.longitude, 109.012345);
  assertEquals(vRvai.row?.responder_email, "budi.sales@example.com");

  const vDismantle = validateWebhookPayload(buildValidPayload({ category: "DISMANTLE", coordinates: "" }));
  assertTrue(vDismantle.valid);
  assertEquals(vDismantle.row?.category, "dismantle");
  assertEquals(vDismantle.row?.latitude, null);
  assertEquals(vDismantle.row?.longitude, null);

  const vUnpaid = validateWebhookPayload(buildValidPayload({ category: "UNPAID" }));
  assertTrue(vUnpaid.valid);
  assertEquals(vUnpaid.row?.category, "unpaid");
});

Deno.test("Upsert idempoten dengan fake store dan log tidak membocorkan email/catatan", async () => {
  const store = new FakeStore();
  const logs: string[] = [];
  const payload = buildValidPayload({
    note: "CATATAN RAHASIA PELANGGAN 999",
    responder_email: "rahasia.sales@example.com",
  });

  const makeReq = () =>
    new Request("https://example.supabase.co/functions/v1/visit-form-webhook", {
      method: "POST",
      headers: { "x-webhook-secret": TEST_SECRET },
      body: JSON.stringify(payload),
    });

  const res1 = await handleWebhookRequest(makeReq(), {
    expectedSecret: TEST_SECRET,
    store,
    logger: (m) => logs.push(m),
  });
  assertEquals(res1.status, 200);
  assertEquals(await res1.json(), { ok: true });

  // Kirim kedua kali dengan response_key sama -> tidak menggandakan baris
  const res2 = await handleWebhookRequest(makeReq(), {
    expectedSecret: TEST_SECRET,
    store,
    logger: (m) => logs.push(m),
  });
  assertEquals(res2.status, 200);
  assertEquals(store.rows.size, 1);

  // Pastikan log tidak mengandung email ataupun isi catatan
  const combinedLogs = logs.join("\n");
  assertTrue(!combinedLogs.includes("rahasia.sales@example.com"), "Log tidak boleh memuat email");
  assertTrue(!combinedLogs.includes("CATATAN RAHASIA PELANGGAN 999"), "Log tidak boleh memuat catatan");
});

