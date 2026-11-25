import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../home/application/home_providers.dart';
import '../domain/my_week.dart';
import '../domain/team_week.dart';

final teamWeekProvider = FutureProvider.autoDispose<TeamWeek>((ref) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(teamRepositoryProvider).teamWeek();
});

/// Mi semana: la actual (`null`) o la semana número N.
final myWeekProvider = FutureProvider.autoDispose.family<MyWeek, int?>((ref, week) {
  ref.watch(sessionMemberIdProvider);
  return ref.watch(teamRepositoryProvider).myWeek(weekNumber: week);
});

/// Subir evidencia cambia «Mi semana», el Inicio y el equipo.
void refreshTeamData(WidgetRef ref) {
  ref
    ..invalidate(myWeekProvider)
    ..invalidate(teamHomeProvider)
    ..invalidate(teamWeekProvider);
}
