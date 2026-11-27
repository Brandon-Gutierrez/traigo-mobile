import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/config/app_config.dart';
import 'package:traigo/core/providers.dart';
import 'package:traigo/features/attendance/data/attendance_api.dart';
import 'package:traigo/features/attendance/data/attendance_location.dart';
import 'package:traigo/features/attendance/presentation/attendance_screen.dart';
import 'package:traigo/features/auth/application/session_controller.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  testWidgets(
    'solicita ubicación tras pulsar y confirma con la hora del servidor',
    (tester) async {
      final harness = ApiHarness();
      final shift = {
        'id': '1',
        'site': 'Sede principal',
        'starts_at': '2026-12-01T08:00:00-04:00',
        'ends_at': '2026-12-01T17:00:00-04:00',
        'active': true,
        'cancelled': false,
        'entry_at': null,
        'exit_at': null,
      };
      const markedAt = '2026-12-01T08:00:04-04:00';
      harness.adapter
        ..reply(200, {
          'data': [shift],
        })
        ..reply(200, {
          'data': {
            'accepted': true,
            'marked_at': markedAt,
            'message': 'Asistencia registrada.',
          },
        })
        ..reply(200, {
          'data': [
            {...shift, 'entry_at': markedAt},
          ],
        });
      var readings = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                mode: DataMode.live,
                baseUrl: 'http://test.local/api/v1',
              ),
            ),
            sessionMemberIdProvider.overrideWithValue('test-member'),
            apiClientProvider.overrideWithValue(harness.api),
            attendanceLocationProvider.overrideWithValue(() async {
              readings++;
              return AttendanceFix(
                latitude: -17,
                longitude: -63,
                accuracy: 10,
                capturedAt: DateTime.parse('2026-12-01T08:00:00-04:00'),
              );
            }),
          ],
          child: const MaterialApp(home: AttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(readings, 0);
      expect(harness.adapter.requests.single.method, 'GET');

      await tester.tap(find.text('Marcar entrada'));
      await tester.pumpAndSettle();

      expect(readings, 1);
      final sent = harness.adapter.requests[1];
      expect(sent.path, '/me/attendance');
      expect(sent.headers['Idempotency-Key'], isNotEmpty);
      expect(sent.data, {
        'assignment_id': '1',
        'kind': 'entry',
        'latitude': -17,
        'longitude': -63,
        'accuracy_m': 10,
        'captured_at': '2026-12-01T12:00:00.000Z',
      });
      expect(find.textContaining('Asistencia registrada.'), findsOneWidget);
      expect(find.text('Marcar salida'), findsOneWidget);
    },
  );
}
