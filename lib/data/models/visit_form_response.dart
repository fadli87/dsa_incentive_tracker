import 'visit_activity.dart';

/// Model jawaban Google Form dari tabel `public.visit_form_responses` (via RPC `get_form_response_for_visit`).
class VisitFormResponse {
  final String id;
  final String responseKey;
  final DateTime? submittedAt;
  final String responderEmail;
  final String? visitDate;
  final String salesName;
  final String spvName;
  final String tscName;
  final String customerId;
  final VisitCategory? category;
  final String visitStatus;
  final String result;
  final List<String> obstacles;
  final String note;
  final double? latitude;
  final double? longitude;
  final String followUp;
  final String? followUpDate;
  final List<String> photoUrls;
  final String? matchedUserId;
  final String? matchedVisitId;

  const VisitFormResponse({
    required this.id,
    required this.responseKey,
    this.submittedAt,
    this.responderEmail = '',
    this.visitDate,
    this.salesName = '',
    this.spvName = '',
    this.tscName = '',
    required this.customerId,
    this.category,
    this.visitStatus = '',
    this.result = '',
    this.obstacles = const [],
    this.note = '',
    this.latitude,
    this.longitude,
    this.followUp = '',
    this.followUpDate,
    this.photoUrls = const [],
    this.matchedUserId,
    this.matchedVisitId,
  });

  /// Hanya mengembalikan URL foto yang aman dan diawali `https://drive.google.com/`.
  List<String> get safeDrivePhotoUrls =>
      photoUrls.where((u) => isSafeGoogleDriveUrl(u)).toList();

  static bool isSafeGoogleDriveUrl(String? rawUrl) {
    if (rawUrl == null) return false;
    final trimmed = rawUrl.trim();
    return trimmed.startsWith('https://drive.google.com/');
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  factory VisitFormResponse.fromJson(Map<String, dynamic> json) {
    final rawCat = json['category']?.toString();
    return VisitFormResponse(
      id: (json['id']?.toString() ?? '').trim(),
      responseKey: (json['response_key']?.toString() ?? '').trim(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      responderEmail: (json['responder_email']?.toString() ?? '').trim(),
      visitDate: json['visit_date']?.toString().trim(),
      salesName: (json['sales_name']?.toString() ?? '').trim(),
      spvName: (json['spv_name']?.toString() ?? '').trim(),
      tscName: (json['tsc_name']?.toString() ?? '').trim(),
      customerId: (json['customer_id']?.toString() ?? '').trim(),
      category: rawCat != null && rawCat.isNotEmpty
          ? VisitCategory.fromString(rawCat)
          : null,
      visitStatus: (json['visit_status']?.toString() ?? '').trim(),
      result: (json['result']?.toString() ?? '').trim(),
      obstacles: _parseStringList(json['obstacles']),
      note: (json['note']?.toString() ?? '').trim(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      followUp: (json['follow_up']?.toString() ?? '').trim(),
      followUpDate: json['follow_up_date']?.toString().trim(),
      photoUrls: _parseStringList(json['photo_urls']),
      matchedUserId: json['matched_user_id']?.toString(),
      matchedVisitId: json['matched_visit_id']?.toString(),
    );
  }
}

/// Baris jawaban Google Form tanpa pasangan dari RPC `get_unmatched_form_responses` (khusus SuperAdmin).
class UnmatchedFormResponseItem {
  final String id;
  final DateTime? submittedAt;
  final String responderEmail;
  final String customerId;
  final String category;
  final String? visitDate;
  final String reason; // 'email_tidak_cocok' | 'visit_tidak_ditemukan'

  const UnmatchedFormResponseItem({
    required this.id,
    this.submittedAt,
    required this.responderEmail,
    required this.customerId,
    this.category = '',
    this.visitDate,
    required this.reason,
  });

  String get reasonDisplayLabel {
    switch (reason) {
      case 'email_tidak_cocok':
        return 'Email tidak cocok dengan akun sales';
      case 'visit_tidak_ditemukan':
        return 'Target visit tidak ditemukan (±3 hari)';
      default:
        return reason;
    }
  }

  factory UnmatchedFormResponseItem.fromJson(Map<String, dynamic> json) {
    return UnmatchedFormResponseItem(
      id: (json['id']?.toString() ?? '').trim(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      responderEmail: (json['responder_email']?.toString() ?? '').trim(),
      customerId: (json['customer_id']?.toString() ?? '').trim(),
      category: (json['category']?.toString() ?? '').trim(),
      visitDate: json['visit_date']?.toString().trim(),
      reason: (json['reason']?.toString() ?? '').trim(),
    );
  }
}
