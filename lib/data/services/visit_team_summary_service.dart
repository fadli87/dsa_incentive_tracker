import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../models/visit_activity.dart';
import '../models/visit_form_response.dart';

/// Model agregasi rekap visit per sales untuk SPV/TSC/Admin/Superadmin
class SalesVisitSummary {
  final String memberId;
  final String memberName;
  final String memberEmail;
  final int total;
  final int formSubmittedTotal;
  final Map<VisitCategory, int> byCategory;
  final Map<VisitStatus, int> byStatus;

  const SalesVisitSummary({
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    required this.total,
    this.formSubmittedTotal = 0,
    required this.byCategory,
    required this.byStatus,
  });

  String get displayName =>
      memberName.trim().isNotEmpty ? memberName : (memberEmail.isNotEmpty ? memberEmail : memberId);

  SalesVisitSummary copyWith({
    int? formSubmittedTotal,
  }) {
    return SalesVisitSummary(
      memberId: memberId,
      memberName: memberName,
      memberEmail: memberEmail,
      total: total,
      formSubmittedTotal: formSubmittedTotal ?? this.formSubmittedTotal,
      byCategory: byCategory,
      byStatus: byStatus,
    );
  }

  /// Mengagregasi baris mentah hasil RPC `public.get_visit_summary(from_date, to_date)`
  /// menjadi daftar ringkasan per sales.
  static List<SalesVisitSummary> aggregateRpcRows(
    List<Map<String, dynamic>> rawRows, {
    Map<String, int> formSubmittedByMember = const {},
  }) {
    final grouped = <String, _MutableSalesAcc>{};

    for (final row in rawRows) {
      final memberId = (row['member_id']?.toString()) ?? '';
      if (memberId.isEmpty) continue;

      final memberName = (row['member_name'] as String?) ?? '';
      final memberEmail = (row['member_email'] as String?) ?? '';
      final cat = VisitCategory.fromString(row['category'] as String?);
      final st = VisitStatus.fromString(row['status'] as String?);
      final count = (row['total'] as num?)?.toInt() ?? 0;
      final formCount = (row['form_submitted_total'] as num?)?.toInt() ?? 0;

      final acc = grouped.putIfAbsent(
        memberId,
        () => _MutableSalesAcc(
          memberId: memberId,
          memberName: memberName,
          memberEmail: memberEmail,
        ),
      );
      acc.total += count;
      acc.formSubmittedTotal += formCount;
      acc.byCategory[cat] = (acc.byCategory[cat] ?? 0) + count;
      acc.byStatus[st] = (acc.byStatus[st] ?? 0) + count;
    }

    final list = grouped.values
        .map(
          (a) => SalesVisitSummary(
            memberId: a.memberId,
            memberName: a.memberName,
            memberEmail: a.memberEmail,
            total: a.total,
            formSubmittedTotal:
                formSubmittedByMember[a.memberId] ?? a.formSubmittedTotal,
            byCategory: Map.unmodifiable(a.byCategory),
            byStatus: Map.unmodifiable(a.byStatus),
          ),
        )
        .toList();

    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}

class _MutableSalesAcc {
  final String memberId;
  final String memberName;
  final String memberEmail;
  int total = 0;
  int formSubmittedTotal = 0;
  final Map<VisitCategory, int> byCategory = {
    VisitCategory.rvai: 0,
    VisitCategory.dismantle: 0,
    VisitCategory.unpaid: 0,
  };
  final Map<VisitStatus, int> byStatus = {
    VisitStatus.belum: 0,
    VisitStatus.sudahVisit: 0,
    VisitStatus.followUp: 0,
  };

  _MutableSalesAcc({
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
  });
}

/// Gateway abstrak untuk query RPC rekap & daftar visit per sales (agar mudah di-fake di test)
abstract class VisitSummaryRemoteGateway {
  Future<List<Map<String, dynamic>>> callGetVisitSummary({
    required String fromDate,
    required String toDate,
  });

  Future<List<Map<String, dynamic>>> fetchMemberVisitsPage({
    required String memberId,
    required String fromDate,
    required String toDate,
    VisitCategory? category,
    VisitStatus? status,
    required int fromIndex,
    required int toIndex,
  });

  /// Mengambil jumlah visit yang `form_submitted = true` per `user_id` pada rentang tanggal.
  Future<Map<String, int>> fetchFormSubmittedCountsByMember({
    required String fromDate,
    required String toDate,
  }) async => const {};

  /// Mengambil jawaban Google Form untuk satu visit berdasarkan `client_id` + `user_id`.
  Future<Map<String, dynamic>?> fetchFormResponseForMemberVisit({
    required String memberId,
    required String clientId,
  }) async => null;
}

class SupabaseVisitSummaryGateway implements VisitSummaryRemoteGateway {
  final SupabaseClient? _injectedClient;
  const SupabaseVisitSummaryGateway([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  @override
  Future<List<Map<String, dynamic>>> callGetVisitSummary({
    required String fromDate,
    required String toDate,
  }) async {
    final res = await _client.rpc(
      'get_visit_summary',
      params: {
        'from_date': fromDate,
        'to_date': toDate,
      },
    ).timeout(const Duration(seconds: 10));

    return (res as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, int>> fetchFormSubmittedCountsByMember({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final res = await _client
          .from('visit_activities')
          .select('user_id')
          .eq('form_submitted', true)
          .isFilter('deleted_at', null)
          .gte('planned_date', fromDate)
          .lte('planned_date', toDate)
          .timeout(const Duration(seconds: 10));

      final counts = <String, int>{};
      for (final item in (res as List<dynamic>)) {
        if (item is Map) {
          final uid = item['user_id']?.toString() ?? '';
          if (uid.isNotEmpty) {
            counts[uid] = (counts[uid] ?? 0) + 1;
          }
        }
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchFormResponseForMemberVisit({
    required String memberId,
    required String clientId,
  }) async {
    final rows = await _client
        .from('visit_activities')
        .select('id')
        .eq('user_id', memberId)
        .eq('client_id', clientId)
        .limit(1)
        .timeout(const Duration(seconds: 10));

    String? visitUuid;
    if (rows.isNotEmpty) {
      visitUuid = rows.first['id']?.toString();
    }
    if (visitUuid == null || visitUuid.isEmpty) return null;

    final res = await _client
        .rpc('get_form_response_for_visit', params: {'p_visit_id': visitUuid})
        .timeout(const Duration(seconds: 10));
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMemberVisitsPage({
    required String memberId,
    required String fromDate,
    required String toDate,
    VisitCategory? category,
    VisitStatus? status,
    required int fromIndex,
    required int toIndex,
  }) async {
    var query = _client
        .from('visit_activities')
        .select()
        .eq('user_id', memberId)
        .isFilter('deleted_at', null)
        .gte('planned_date', fromDate)
        .lte('planned_date', toDate);

    if (category != null) {
      query = query.eq('category', category.toDbString());
    }
    if (status != null) {
      query = query.eq('status', status.toDbString());
    }

    final res = await query
        .order('planned_date', ascending: false)
        .range(fromIndex, toIndex)
        .timeout(const Duration(seconds: 10));

    return (res as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

/// Service Read-Only untuk Rekap Tim (SPV / TSC / Admin / Superadmin)
class VisitTeamSummaryService {
  static const int pageSize = 50;

  final VisitSummaryRemoteGateway _gateway;

  VisitTeamSummaryService({
    SupabaseClient? supabaseClient,
    VisitSummaryRemoteGateway? remoteGateway,
  }) : _gateway = remoteGateway ?? SupabaseVisitSummaryGateway(supabaseClient);

  Future<List<SalesVisitSummary>> fetchTeamSummary({
    required String fromDate,
    required String toDate,
  }) async {
    final rows = await _gateway.callGetVisitSummary(
      fromDate: fromDate,
      toDate: toDate,
    );
    final formCounts = await _gateway.fetchFormSubmittedCountsByMember(
      fromDate: fromDate,
      toDate: toDate,
    );
    return SalesVisitSummary.aggregateRpcRows(
      rows,
      formSubmittedByMember: formCounts,
    );
  }

  Future<VisitFormResponse?> fetchFormResponseForMemberVisit({
    required String memberId,
    required String clientId,
  }) async {
    try {
      final map = await _gateway.fetchFormResponseForMemberVisit(
        memberId: memberId,
        clientId: clientId,
      );
      if (map == null) return null;
      return VisitFormResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<List<VisitActivity>> fetchMemberVisits({
    required String memberId,
    required String fromDate,
    required String toDate,
    VisitCategory? category,
    VisitStatus? status,
    int page = 0,
  }) async {
    final fromIdx = page * pageSize;
    final toIdx = fromIdx + pageSize - 1;
    final rows = await _gateway.fetchMemberVisitsPage(
      memberId: memberId,
      fromDate: fromDate,
      toDate: toDate,
      category: category,
      status: status,
      fromIndex: fromIdx,
      toIndex: toIdx,
    );
    return rows.map((r) => VisitActivity.fromSupabaseJson(r)).toList();
  }
}

