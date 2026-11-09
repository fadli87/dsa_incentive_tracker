import '../../data/models/master_customer.dart';

/// Konstanta bisnis terpusat untuk fitur Aktivitas Harian Visit & Master Pelanggan KCLP.
class VisitConstants {
  VisitConstants._();

  /// Kunjungan RVAI disarankan tepat 7 hari setelah `install_date`.
  static const int rvaiDueDays = 7;

  /// Batas maksimal hari ke belakang sejak `dueDate` agar data lama tidak membanjiri daftar saran RVAI.
  static const int rvaiLookbackDays = 30;
}

/// Model item saran RVAI yang dihitung secara murni dari `MasterCustomer`.
class RvaiSuggestionItem {
  final MasterCustomer customer;
  final DateTime dueDate;
  final int daysPastDue;

  const RvaiSuggestionItem({
    required this.customer,
    required this.dueDate,
    required this.daysPastDue,
  });

  String get dueLabel {
    if (daysPastDue <= 0) {
      return 'Jatuh tempo hari ini';
    }
    return 'Jatuh tempo $daysPastDue hari lalu';
  }
}

/// Fungsi murni (pure function) untuk menghitung daftar saran RVAI:
/// - `dueDate = installDate + rvaiDueDays (7)`
/// - Disarankan bila `dueDate <= today` DAN `today - dueDate <= rvaiLookbackDays (30)`
/// - DAN belum ada visit `rvai` aktif (`existingRvaiCustomerIds`) untuk `customer_id` tersebut.
/// - Diurutkan dari yang paling lama jatuh tempo (`dueDate` paling awal / `daysPastDue` terbesar).
List<RvaiSuggestionItem> computeRvaiSuggestions({
  required Iterable<MasterCustomer> masterCustomers,
  required Set<String> existingRvaiCustomerIds,
  required DateTime today,
  int dueDays = VisitConstants.rvaiDueDays,
  int lookbackDays = VisitConstants.rvaiLookbackDays,
}) {
  final todayDateOnly = DateTime(today.year, today.month, today.day);
  final suggestions = <RvaiSuggestionItem>[];

  for (final customer in masterCustomers) {
    final cid = customer.customerId.trim();
    if (cid.isEmpty) continue;
    if (existingRvaiCustomerIds.contains(cid)) continue;

    final rawInstall = customer.installDate;
    if (rawInstall == null) continue;

    final installDateOnly = DateTime(
      rawInstall.year,
      rawInstall.month,
      rawInstall.day,
    );
    final dueDate = installDateOnly.add(Duration(days: dueDays));
    final daysPastDue = todayDateOnly.difference(dueDate).inDays;

    if (daysPastDue >= 0 && daysPastDue <= lookbackDays) {
      suggestions.add(
        RvaiSuggestionItem(
          customer: customer,
          dueDate: dueDate,
          daysPastDue: daysPastDue,
        ),
      );
    }
  }

  suggestions.sort((a, b) {
    final cmp = b.daysPastDue.compareTo(a.daysPastDue);
    if (cmp != 0) return cmp;
    return a.customer.customerId.compareTo(b.customer.customerId);
  });

  return suggestions;
}

