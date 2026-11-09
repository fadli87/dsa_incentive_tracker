/**
 * Google Apps Script Trigger: Sinkronisasi Jawaban Google Form -> Supabase Edge Function
 *
 * ATURAN KEAMANAN (PUBLIC REPO):
 * - JANGAN menulis nilai FORM_ID, WEBHOOK_URL, atau WEBHOOK_SECRET secara langsung di file ini!
 * - Seluruh konfigurasi dibaca dari Script Properties (Project Settings -> Script Properties):
 *     1. FORM_ID        : ID Google Form (dari URL edit /d/<FORM_ID>/edit)
 *     2. WEBHOOK_URL    : https://<PROJECT_REF>.supabase.co/functions/v1/visit-form-webhook
 *     3. WEBHOOK_SECRET : String acak >= 32 karakter (sama dengan VISIT_FORM_WEBHOOK_SECRET di Supabase)
 */

var QUESTION_TITLES = {
  VISIT_DATE: 'Tanggal Visit',
  SALES_NAME: 'Nama Sales',
  SPV_NAME: 'Nama SPV',
  TSC_NAME: 'TSC',
  CUSTOMER_ID: 'Customer ID',
  CATEGORY: 'Kategori Visit',
  VISIT_STATUS: 'Status Visit',
  RESULT: 'Hasil Kunjungan',
  OBSTACLES: 'Kendala Utama (jika ada)',
  NOTE: 'Catatan / Detail Kunjungan',
  COORDINATES: 'Koordinat Lokasi Visit (opsional)',
  FOLLOW_UP: 'Tindak Lanjut',
  FOLLOW_UP_DATE: 'Tanggal Tindak Lanjut (jika ada)',
  PHOTO_UPLOAD: 'Foto Bukti Visit'
};

var RESYNC_CURSOR_PROP = 'RESYNC_CURSOR_INDEX';
var MAX_EXECUTION_MS = 270 * 1000; // Berhenti aman sebelum batas ~5 menit (270 detik)

/**
 * Membaca konfigurasi wajib dari Script Properties.
 */
function getConfig_() {
  var props = PropertiesService.getScriptProperties();
  var formId = (props.getProperty('FORM_ID') || '').trim();
  var webhookUrl = (props.getProperty('WEBHOOK_URL') || '').trim();
  var webhookSecret = (props.getProperty('WEBHOOK_SECRET') || '').trim();

  if (!formId || !webhookUrl || !webhookSecret) {
    throw new Error(
      'Script Properties belum lengkap. Pastikan FORM_ID, WEBHOOK_URL, dan WEBHOOK_SECRET sudah diisi di Project Settings.'
    );
  }
  return {
    formId: formId,
    webhookUrl: webhookUrl,
    webhookSecret: webhookSecret
  };
}

/**
 * 1. Memasang trigger onFormSubmit pada Google Form (menghapus trigger lama bernama sama terlebih dahulu).
 */
function installTrigger() {
  var cfg = getConfig_();
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'onFormSubmit') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }

  var form = FormApp.openById(cfg.formId);
  ScriptApp.newTrigger('onFormSubmit')
    .forForm(form)
    .onFormSubmit()
    .create();

  Logger.log('Trigger onFormSubmit berhasil dipasang untuk Form ID.');
}

/**
 * Memformat nilai jawaban tanggal ke yyyy-MM-dd (zona Asia/Jakarta).
 */
function formatDateAnswer_(rawVal) {
  if (!rawVal) return null;
  if (rawVal instanceof Date) {
    return Utilities.formatDate(rawVal, 'Asia/Jakarta', 'yyyy-MM-dd');
  }
  var text = String(rawVal).trim();
  if (!text) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
    return text;
  }
  var parsed = new Date(text);
  if (!isNaN(parsed.getTime())) {
    return Utilities.formatDate(parsed, 'Asia/Jakarta', 'yyyy-MM-dd');
  }
  return text.substring(0, 10);
}

/**
 * Mengubah daftar ID file Google Drive dari pertanyaan Upload menjadi URL Drive standar.
 */
function toDriveUrls_(rawFiles) {
  if (!rawFiles) return [];
  var ids = Array.isArray(rawFiles) ? rawFiles : [rawFiles];
  var urls = [];
  for (var i = 0; i < ids.length; i++) {
    var id = String(ids[i] || '').trim();
    if (id) {
      if (id.indexOf('https://drive.google.com/') === 0) {
        urls.push(id);
      } else {
        urls.push('https://drive.google.com/file/d/' + id + '/view');
      }
    }
  }
  return urls;
}

/**
 * Membentuk objek payload JSON dari satu objek FormResponse.
 */
function buildPayloadFromResponse_(formResponse) {
  var itemResponses = formResponse.getItemResponses();
  var timestamp = formResponse.getTimestamp();
  var submittedIso = timestamp ? new Date(timestamp).toISOString() : new Date().toISOString();

  var payload = {
    response_key: String(formResponse.getId() || '').trim(),
    submitted_at: submittedIso,
    responder_email: String(formResponse.getRespondentEmail() || '').trim().toLowerCase(),
    visit_date: null,
    sales_name: '',
    spv_name: '',
    tsc_name: '',
    customer_id: '',
    category: '',
    visit_status: '',
    result: '',
    obstacles: [],
    note: '',
    coordinates: '',
    follow_up: '',
    follow_up_date: null,
    photo_urls: []
  };

  for (var i = 0; i < itemResponses.length; i++) {
    var itemResp = itemResponses[i];
    var title = String(itemResp.getItem().getTitle() || '').trim();
    var answer = itemResp.getResponse();

    switch (title) {
      case QUESTION_TITLES.VISIT_DATE:
        payload.visit_date = formatDateAnswer_(answer);
        break;
      case QUESTION_TITLES.SALES_NAME:
        payload.sales_name = String(answer || '').trim();
        break;
      case QUESTION_TITLES.SPV_NAME:
        payload.spv_name = String(answer || '').trim();
        break;
      case QUESTION_TITLES.TSC_NAME:
        payload.tsc_name = String(answer || '').trim();
        break;
      case QUESTION_TITLES.CUSTOMER_ID:
        payload.customer_id = String(answer || '').trim();
        break;
      case QUESTION_TITLES.CATEGORY:
        payload.category = String(answer || '').trim();
        break;
      case QUESTION_TITLES.VISIT_STATUS:
        payload.visit_status = String(answer || '').trim();
        break;
      case QUESTION_TITLES.RESULT:
        payload.result = String(answer || '').trim();
        break;
      case QUESTION_TITLES.OBSTACLES:
        if (Array.isArray(answer)) {
          payload.obstacles = answer.map(function (x) { return String(x || '').trim(); }).filter(Boolean);
        } else if (answer) {
          payload.obstacles = [String(answer).trim()];
        }
        break;
      case QUESTION_TITLES.NOTE:
        payload.note = String(answer || '').trim();
        break;
      case QUESTION_TITLES.COORDINATES:
        payload.coordinates = String(answer || '').trim();
        break;
      case QUESTION_TITLES.FOLLOW_UP:
        payload.follow_up = String(answer || '').trim();
        break;
      case QUESTION_TITLES.FOLLOW_UP_DATE:
        payload.follow_up_date = formatDateAnswer_(answer);
        break;
      case QUESTION_TITLES.PHOTO_UPLOAD:
        payload.photo_urls = toDriveUrls_(answer);
        break;
      default:
        break;
    }
  }

  return payload;
}

/**
 * Mencatat kegagalan pengiriman ke sheet SYNC_ERRORS di spreadsheet tujuan Form (tanpa isi jawaban/email).
 */
function logSyncError_(formId, responseKey, statusCode) {
  try {
    var form = FormApp.openById(formId);
    var destId = form.getDestinationId();
    if (!destId) return;

    var ss = SpreadsheetApp.openById(destId);
    var sheet = ss.getSheetByName('SYNC_ERRORS');
    if (!sheet) {
      sheet = ss.insertSheet('SYNC_ERRORS');
      sheet.appendRow(['Timestamp', 'Response Key', 'HTTP Status']);
    }
    sheet.appendRow([new Date().toISOString(), String(responseKey || ''), String(statusCode)]);
  } catch (err) {
    Logger.log('Gagal menulis SYNC_ERRORS: ' + err);
  }
}

/**
 * Mengirim payload ke Supabase Edge Function dengan hingga 3 percobaan (exponential backoff untuk >=500 atau network error).
 */
function postToWebhook_(cfg, payload) {
  var maxAttempts = 3;
  var lastStatus = 0;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      var res = UrlFetchApp.fetch(cfg.webhookUrl, {
        method: 'post',
        contentType: 'application/json',
        headers: {
          'x-webhook-secret': cfg.webhookSecret
        },
        payload: JSON.stringify(payload),
        muteHttpExceptions: true
      });
      lastStatus = res.getResponseCode();
      if (lastStatus >= 200 && lastStatus < 300) {
        Logger.log('Webhook OK response_key=' + payload.response_key + ' status=' + lastStatus);
        return true;
      }
      if (lastStatus < 500) {
        // Error validasi 4xx tidak perlu di-retry
        Logger.log('Webhook rejected response_key=' + payload.response_key + ' status=' + lastStatus);
        break;
      }
    } catch (netErr) {
      lastStatus = -1;
      Logger.log('Network error attempt ' + attempt + ' response_key=' + payload.response_key);
    }

    if (attempt < maxAttempts) {
      Utilities.sleep(attempt * 1500);
    }
  }

  logSyncError_(cfg.formId, payload.response_key, lastStatus);
  return false;
}

/**
 * 2. Handler utama saat jawaban Google Form dikirim (On form submit).
 */
function onFormSubmit(e) {
  var cfg = getConfig_();
  var formResponse = e && e.response ? e.response : null;
  if (!formResponse) {
    var form = FormApp.openById(cfg.formId);
    var all = form.getResponses();
    if (all.length === 0) return;
    formResponse = all[all.length - 1];
  }

  var payload = buildPayloadFromResponse_(formResponse);
  postToWebhook_(cfg, payload);
}

/**
 * 3. Mengirim ulang seluruh respons yang ada di Google Form secara bertahap (idempoten).
 * Menyimpan posisi kursor di Script Properties bila waktu eksekusi mendekati 5 menit.
 */
function resyncAll() {
  var startTime = Date.now();
  var cfg = getConfig_();
  var props = PropertiesService.getScriptProperties();
  var form = FormApp.openById(cfg.formId);
  var responses = form.getResponses();

  var startIndex = parseInt(props.getProperty(RESYNC_CURSOR_PROP) || '0', 10);
  if (isNaN(startIndex) || startIndex < 0 || startIndex >= responses.length) {
    startIndex = 0;
  }

  var sentCount = 0;
  for (var i = startIndex; i < responses.length; i++) {
    if (Date.now() - startTime >= MAX_EXECUTION_MS) {
      props.setProperty(RESYNC_CURSOR_PROP, String(i));
      Logger.log('Batas waktu hampir tercapai. Posisi disimpan pada indeks ' + i + ' dari ' + responses.length);
      return;
    }

    var payload = buildPayloadFromResponse_(responses[i]);
    postToWebhook_(cfg, payload);
    sentCount++;
    Utilities.sleep(250);
  }

  props.deleteProperty(RESYNC_CURSOR_PROP);
  Logger.log('resyncAll selesai. Total terkirim dalam sesi ini: ' + sentCount);
}

/**
 * 4. Mengirim hanya 1 respons terbaru untuk pengujian cepat.
 */
function sendLatestAsTest() {
  var cfg = getConfig_();
  var form = FormApp.openById(cfg.formId);
  var responses = form.getResponses();
  if (responses.length === 0) {
    Logger.log('Belum ada respons di Google Form.');
    return;
  }
  var latest = responses[responses.length - 1];
  var payload = buildPayloadFromResponse_(latest);
  var ok = postToWebhook_(cfg, payload);
  Logger.log('sendLatestAsTest response_key=' + payload.response_key + ' ok=' + ok);
}

