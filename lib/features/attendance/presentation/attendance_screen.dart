import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../auth/application/session_controller.dart';
import '../data/attendance_api.dart';
import '../data/attendance_location.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _busy = false;
  String? _message;
  LocationIssue? _locationIssue;
  final _retryKeys = <(String, AttendanceKind), String>{};

  Future<void> _refresh() async {
    ref.invalidate(attendanceShiftsProvider);
    await ref.read(attendanceShiftsProvider.future);
  }

  Future<void> _mark(AttendanceShift shift, AttendanceKind kind) async {
    if (_busy) return;
    final memberId = ref.read(sessionMemberIdProvider);
    if (memberId == null) return;
    final intent = (shift.id, kind);
    final key = _retryKeys[intent] ?? const Uuid().v4();
    setState(() {
      _busy = true;
      _message = null;
      _locationIssue = null;
    });

    try {
      final fix = await ref.read(attendanceLocationProvider)();
      if (!mounted || ref.read(sessionMemberIdProvider) != memberId) {
        return;
      }
      _retryKeys[intent] = key;
      final result = await ref
          .read(attendanceApiProvider)
          .mark(shiftId: shift.id, kind: kind, fix: fix, key: key);
      _retryKeys.remove(intent);
      if (!mounted) return;
      setState(() {
        _message = result.markedAt == null
            ? result.message
            : '${result.message} ${_clock(result.markedAt!)}';
      });
      ref.invalidate(attendanceShiftsProvider);
    } on LocationIssue catch (issue) {
      if (mounted) {
        setState(() {
          _locationIssue = issue;
          _message = issue.message;
        });
      }
    } catch (error) {
      if (error is ValidationException ||
          error is ConflictException ||
          error is NotFoundException) {
        _retryKeys.remove(intent);
      }
      if (mounted) setState(() => _message = errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _clock(DateTime date) =>
      DateFormat('dd/MM HH:mm').format(date.toLocal());

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(appConfigProvider).isDemo;
    final shifts = demo ? null : ref.watch(attendanceShiftsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia')),
      body: RefreshablePage(
        onRefresh: demo ? () async {} : _refresh,
        children: [
          if (demo)
            const Text(
              'La asistencia está disponible al conectarte al servidor.',
            )
          else ...[
            const Text(
              'Usamos tu ubicación solo cuando pulsas para marcar. '
              'El servidor comprueba el rango de la sede y guarda el resultado, '
              'sin guardar las coordenadas de tu teléfono.',
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_message case final message?) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(message)),
              if (_locationIssue == LocationIssue.settings)
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Abrir ajustes de la app'),
                ),
              if (_locationIssue == LocationIssue.disabled)
                TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: const Text('Abrir ajustes de ubicación'),
                ),
            ],
            const SizedBox(height: 20),
            ...shifts!.when(
              data: (items) => items.isEmpty
                  ? const [Text('No tienes turnos asignados por ahora.')]
                  : items.map(_shift).toList(),
              error: (error, _) => [
                ErrorPanel(
                  message: errorMessage(error),
                  onRetry: () => ref.invalidate(attendanceShiftsProvider),
                ),
              ],
              loading: () => const [LinearProgressIndicator()],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shift(AttendanceShift shift) {
    final kind = shift.nextKind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(shift.site),
        Text('${_clock(shift.startsAt)} – ${_clock(shift.endsAt)}'),
        if (shift.cancelled) const Text('Turno cancelado'),
        LeaderRow(
          'Entrada',
          shift.entryAt == null ? '—' : _clock(shift.entryAt!),
        ),
        LeaderRow('Salida', shift.exitAt == null ? '—' : _clock(shift.exitAt!)),
        if (kind != null) ...[
          const SizedBox(height: 8),
          CutButton(
            label: kind == AttendanceKind.entry
                ? 'Marcar entrada'
                : 'Marcar salida',
            onPressed: _busy ? null : () => _mark(shift, kind),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}
