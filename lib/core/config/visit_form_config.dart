import '../../data/models/visit_activity.dart';

/// Konfigurasi URL dan entry ID Google Form manajemen untuk Aktivitas Harian Visit.
/// Diambil lewat `--dart-define` saat build (tanpa hardcode URL/entry di kode sumber).
class VisitFormConfig {
  VisitFormConfig._();

  static const String formUrl = String.fromEnvironment(
    'VISIT_FORM_URL',
    defaultValue: '',
  );

  static const String customerEntry = String.fromEnvironment(
    'VISIT_FORM_CUSTOMER_ENTRY',
    defaultValue: '',
  );

  static const String categoryEntry = String.fromEnvironment(
    'VISIT_FORM_CATEGORY_ENTRY',
    defaultValue: '',
  );

  static bool get isConfigured => formUrl.trim().isNotEmpty;

  /// Label kategori resmi pada Google Form manajemen:
  /// - rvai -> VISIT RVAI
  /// - dismantle -> DISMANTLE
  /// - unpaid -> UNPAID
  static String categoryLabelForForm(VisitCategory category) {
    switch (category) {
      case VisitCategory.rvai:
        return 'VISIT RVAI';
      case VisitCategory.dismantle:
        return 'DISMANTLE';
      case VisitCategory.unpaid:
        return 'UNPAID';
    }
  }

  /// Membentuk URL Google Form dengan prefill Customer ID dan Kategori.
  /// Mengembalikan `null` bila `baseUrl` kosong.
  /// Parameter opsional digunakan untuk pengujian unit tanpa bergantung pada compile-time environment.
  static String? buildPrefillUrl({
    required String customerId,
    required VisitCategory category,
    String? overrideFormUrl,
    String? overrideCustomerEntry,
    String? overrideCategoryEntry,
  }) {
    final rawUrl = (overrideFormUrl ?? formUrl).trim();
    if (rawUrl.isEmpty) return null;

    final custEntry = (overrideCustomerEntry ?? customerEntry).trim();
    final catEntry = (overrideCategoryEntry ?? categoryEntry).trim();

    final queryParts = <String>['usp=pp_url'];

    if (custEntry.isNotEmpty && customerId.trim().isNotEmpty) {
      final encodedKey = Uri.encodeQueryComponent(custEntry);
      final encodedVal = Uri.encodeQueryComponent(customerId.trim());
      queryParts.add('$encodedKey=$encodedVal');
    }

    if (catEntry.isNotEmpty) {
      final encodedKey = Uri.encodeQueryComponent(catEntry);
      final encodedVal = Uri.encodeQueryComponent(categoryLabelForForm(category));
      queryParts.add('$encodedKey=$encodedVal');
    }

    final separator = rawUrl.contains('?') ? '&' : '?';
    return '$rawUrl$separator${queryParts.join('&')}';
  }

  static Uri? buildPrefillUri({
    required String customerId,
    required VisitCategory category,
    String? overrideFormUrl,
    String? overrideCustomerEntry,
    String? overrideCategoryEntry,
  }) {
    final urlStr = buildPrefillUrl(
      customerId: customerId,
      category: category,
      overrideFormUrl: overrideFormUrl,
      overrideCustomerEntry: overrideCustomerEntry,
      overrideCategoryEntry: overrideCategoryEntry,
    );
    if (urlStr == null) return null;
    return Uri.tryParse(urlStr);
  }
}
