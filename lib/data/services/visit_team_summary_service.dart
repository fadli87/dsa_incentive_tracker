import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../models/visit_activity.dart';

/// Model agregasi rekap visit per sales untuk SPV/TSC/Admin/Superadmin
class SalesVisitSummary {
  final String memberId;
  final String memberName;
  final String memberEmail;
  final int total;
  final Map<VisitCategory, int> byCategory;
  final Map<VisitStatus, int> byStatus;

  const SalesVisitSummary({
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    required this.total,
    required this.byCategory,
    required this.byStatus,
  });

  String get displayName =>
      memberName.trim().isNotEmpty ? memberName : (memberEmail.isNotEmpty ? memberEmail : memberId);

  /// Mengagregasi baris mentah hasil RPC `public.get_visit_summary(from_date, to_date)`
  /// menjadi daftar ringkasan per sales.
  static List<SalesVisitSummary> aggregateRpcRows(List<Map<String, dynamic>> rawRows) {
    final grouped = <String, _MutableSalesAcc>{};

    for (final row in rawRows) {
      final memberId = (row['member_id']?.toString()) ?? '';
      if (memberId.isEmpty) continue;

      final memberName = (row['member_name'] as String?) ?? '';
      final memberEmail = (row['member_email'] as String?) ?? '';
      final cat = VisitCategory.fromString(row['category'] as String?);
      final st = VisitStatus.fromString(row['status'] as String?);
      final count = (row['total'] as num?)?.toInt() ?? 0;

      final acc = grouped.putIfAbsent(
        memberId,
        () => _MutableSalesAcc(
          memberId: memberId,
          memberName: memberName,
          memberEmail: memberEmail,
        ),
      );
      acc.total += count;
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
    return SalesVisitSummary.aggregateRpcRows(rows);
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
