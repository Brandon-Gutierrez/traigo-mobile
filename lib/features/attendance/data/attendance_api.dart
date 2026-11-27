import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';

final attendanceApiProvider = Provider<AttendanceApi>(
  (ref) => AttendanceApi(ref.watch(apiClientProvider)),
);

final attendanceShiftsProvider =
    FutureProvider.autoDispose<List<AttendanceShift>>((ref) {
      if (ref.watch(sessionMemberIdProvider) == null) return const [];
      return ref.watch(attendanceApiProvider).shifts();
    });

enum AttendanceKind { entry, exit }

class AttendanceShift {
  AttendanceShift.fromJson(Json json)
    : id = json.str('id'),
      site = json.str('site'),
      startsAt = json.date('starts_at'),
      endsAt = json.date('ends_at'),
      active = json.flag('active'),
      cancelled = json.flag('cancelled'),
      entryAt = json.dateOrNull('entry_at'),
      exitAt = json.dateOrNull('exit_at');

  final String id;
  final String site;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool active;
  final bool cancelled;
  final DateTime? entryAt;
  final DateTime? exitAt;

  AttendanceKind? get nextKind {
    if (!active || cancelled || exitAt != null) return null;
    return entryAt == null ? AttendanceKind.entry : AttendanceKind.exit;
  }
}

class AttendanceFix {
  const AttendanceFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
}

class AttendanceResult {
  AttendanceResult.fromJson(Json json)
    : accepted = json.flag('accepted'),
      message = json.str('message'),
      markedAt = json.dateOrNull('marked_at');

  final bool accepted;
  final String message;
  final DateTime? markedAt;
}

class AttendanceApi {
  AttendanceApi(this._api);

  final ApiClient _api;

  Future<List<AttendanceShift>> shifts() async =>
      (await _api.get(ApiPaths.attendance))
          .list('data')
          .map(AttendanceShift.fromJson)
          .toList();

  Future<AttendanceResult> mark({
    required String shiftId,
    required AttendanceKind kind,
    required AttendanceFix fix,
    required String key,
  }) async {
    final body = await _api.post(
      ApiPaths.attendance,
      idempotencyKey: key,
      body: {
        'assignment_id': shiftId,
        'kind': kind.name,
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracy_m': fix.accuracy,
        'captured_at': fix.capturedAt.toUtc().toIso8601String(),
      },
    );
    return AttendanceResult.fromJson(body.obj('data'));
  }
}
