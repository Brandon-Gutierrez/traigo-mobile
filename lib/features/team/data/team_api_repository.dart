import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../domain/my_week.dart';
import '../domain/team_week.dart';

/// `2026-11-30`, sin hora.
String apiDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class TeamApiRepository implements TeamRepository {
  TeamApiRepository(this._api);

  final ApiClient _api;

  @override
  Future<TeamWeek> teamWeek() async {
    final json = await _api.get(ApiPaths.teamWeek);
    return TeamWeek.fromJson(json.obj('data'));
  }

  @override
  Future<MyWeek> myWeek({int? weekNumber}) async {
    final json = await _api.get(ApiPaths.myWeek, query: {'week': ?weekNumber});
    return MyWeek.fromJson(json.obj('data'));
  }

  @override
  Future<Evidence> submitEvidence(String resultId, NewEvidence evidence) async {
    final json = await _api.postMultipart(
      ApiPaths.myEvidence(resultId),
      fields: evidence.fields,
      file: evidence.file,
      idempotencyKey: evidence.clientUuid,
    );
    return Evidence.fromJson(json.obj('data'));
  }

  @override
  Future<Deliverable> submitDeliverable(
    String id, {
    required DateTime deliveredOn,
    required String clientUuid,
    UploadFile? file,
    String? url,
  }) async {
    final json = await _api.postMultipart(
      ApiPaths.myDeliverable(id),
      fields: {'delivered_on': apiDate(deliveredOn), 'url': url},
      file: file,
      idempotencyKey: clientUuid,
    );
    return Deliverable.fromJson(json.obj('data'));
  }
}
