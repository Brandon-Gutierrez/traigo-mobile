import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../domain/payouts.dart';

class PayoutsApiRepository implements PayoutsRepository {
  PayoutsApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ComplianceRow>> compliance({int? weekNumber}) async {
    final json = await _api.get(ApiPaths.controlCompliance, query: {'week': ?weekNumber});
    return json.list('data').map(ComplianceRow.fromJson).toList();
  }

  @override
  Future<WeeklyClosing> weeklyClosing({int? weekNumber}) async => _closing(
        await _api.get(ApiPaths.controlWeeklyClosing, query: {'week': ?weekNumber}),
      );

  @override
  Future<WeeklyClosing> sendWeeklyClosing(
    int weekNumber, {
    required bool duplicatesCleared,
    Map<String, String> closePending = const {},
    String? observations,
  }) async =>
      _closing(await _api.post(ApiPaths.controlWeeklyClosingSend(weekNumber), body: {
        'duplicates_cleared': duplicatesCleared,
        'close_pending': [
          for (final MapEntry(key: memberId, value: reason) in closePending.entries)
            {'member_id': memberId, 'reason': reason},
        ],
        'observations': observations,
      }));

  @override
  Future<WeekBonus> bonus({int? weekNumber}) async =>
      _bonus(await _api.get(ApiPaths.controlBonus, query: {'week': ?weekNumber}));

  @override
  Future<WeekBonus> markBonusPaid(int weekNumber, String memberId) async =>
      _bonus(await _api.post(ApiPaths.controlBonusPaid(weekNumber, memberId)));

  @override
  Future<MonthCommissions> commissions(String month) async =>
      _month(await _api.get(ApiPaths.controlCommissions, query: {'month': month}));

  @override
  Future<MonthCommissions> sendCommissions(String month) async =>
      _month(await _api.post(ApiPaths.controlCommissionsSend(month)));

  @override
  Future<MonthCommissions> markCommissionsPaid(String month) async =>
      _month(await _api.post(ApiPaths.controlCommissionsPaid(month)));

  WeeklyClosing _closing(Json json) => WeeklyClosing.fromJson(json.obj('data'));
  WeekBonus _bonus(Json json) => WeekBonus.fromJson(json.obj('data'));
  MonthCommissions _month(Json json) => MonthCommissions.fromJson(json.obj('data'));
}
