import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/paged_result.dart';
import '../domain/admin.dart';

class AdminApiRepository implements AdminRepository {
  AdminApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<PriceSheet> priceSheet(String productId) async =>
      _sheet(await _api.get(ApiPaths.controlProduct(productId)));

  @override
  Future<PriceSheet> proposePrice(
    String productId,
    PriceValues proposed, {
    String? reason,
  }) async =>
      _sheet(await _api.post(ApiPaths.controlPriceChanges(productId), body: {
        'price_unit': ?proposed.priceUnit?.toApi(),
        'price_wholesale': ?proposed.priceWholesale?.toApi(),
        'wholesale_min_qty': ?proposed.wholesaleMinQty,
        'commission_pct': ?proposed.commissionPct?.toStringAsFixed(2),
        'cost': ?proposed.cost?.toApi(),
        'reason': reason,
      }));

  @override
  Future<PagedResult<AuditEntry>> audit({int page = 1}) async {
    final json = await _api.get(ApiPaths.controlAudit, query: {'page': page});
    return PagedResult.fromJson(json, AuditEntry.fromJson);
  }

  @override
  Future<List<int>> downloadReport(ReportType type, {required String period}) =>
      _api.download(ApiPaths.controlReport(type.apiValue), query: {'period': period});

  @override
  Future<SystemStatus> systemStatus() async {
    final json = await _api.get(ApiPaths.controlSystemStatus);
    return SystemStatus.fromJson(json.obj('data'));
  }

  @override
  Future<void> resetPin(String memberId, String newPin) =>
      _api.postNoContent(ApiPaths.controlMemberPin(memberId), body: {'pin': newPin});

  @override
  Future<void> revokeSessions(String memberId) =>
      _api.postNoContent(ApiPaths.controlMemberRevoke(memberId));

  PriceSheet _sheet(Json json) => PriceSheet.fromJson(json.obj('data'));
}
