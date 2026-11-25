import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/rise_in.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../auth/presentation/account_header.dart';
import '../../team/domain/bonus.dart';
import '../../team/presentation/week_block.dart';
import '../application/control_providers.dart';
import '../domain/control_summary.dart';
import '../domain/review.dart';

/// Resumen de Jime y Dirección: la semana, lo que falta revisar, cómo va cada
/// integrante y el bono.
class ControlSummaryScreen extends ConsumerWidget {
  const ControlSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(sessionControllerProvider).value?.member;
    if (member == null || !member.role.isControlSide) return const SizedBox.shrink();
    final summary = ref.watch(controlSummaryProvider);
    final isManagement = member.role == MemberRole.management;

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(controlSummaryProvider);
        return ref.read(controlSummaryProvider.future);
      },
      children: [
        AccountHeader(
          greeting: 'Hola, ${member.firstName}',
          detail: '${isManagement ? 'Dirección' : 'Control'} · ${member.code}',
        ),
        const SizedBox(height: 12),
        ...summary.when(
          data: (data) => [
            RiseIn(
              child: WeekBlock(
                title: 'Semana ${data.week.label} · ${_dayLabel(data.asOf)}',
                percent: data.percent,
                collected: data.collected,
                target: data.week.target,
              ),
            ),
            const SizedBox(height: 14),
            _Pending(data.pending, isManagement: isManagement),
            const SizedBox(height: 14),
            _Members(data.members),
            const SizedBox(height: 14),
            _Bonus(data, isManagement: isManagement),
            if (isManagement) ...[
              const SizedBox(height: 14),
              CutButton(
                label: 'Revisar y autorizar',
                onPressed: () => context.go(AppRoutes.approve),
              ),
            ],
          ],
          loading: () => const [
            SkeletonBlock(height: 126),
            SizedBox(height: 16),
            SkeletonBlock(height: 128),
            SizedBox(height: 16),
            SkeletonBlock(height: 200),
          ],
          error: (error, _) => [
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(controlSummaryProvider),
            ),
          ],
        ),
      ],
    );
  }

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  /// «domingo 6», en la hora del celular.
  static String _dayLabel(DateTime date) {
    final local = date.toLocal();
    return '${_weekdays[local.weekday - 1]} ${local.day}';
  }
}

class _Pending extends StatelessWidget {
  const _Pending(this.pending, {required this.isManagement});

  final PendingReview pending;
  final bool isManagement;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (PendingType.payment, 'Pagos por confirmar', pending.payments),
      (PendingType.evidence, 'Evidencias de KPI', pending.evidence),
      (PendingType.cashClosing, 'Cierres de caja', pending.cashClosings),
      (PendingType.deliverable, 'Entregas de Sistemas', pending.deliverables),
    ];
    final count = AppText.mono(15, weight: FontWeight.w700, color: AppColors.violet);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La bandeja es de Jime: Dirección solo ve cuánto falta.
        SectionHeader(
          isManagement ? 'Por validar de Jime' : 'Por revisar hoy',
          trailing: isManagement
              ? null
              : TextLink('Ver pendientes', onTap: () => context.go(AppRoutes.pending)),
        ),
        if (pending.total == 0)
          Text(
            'No queda nada por revisar.',
            style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
          )
        else
          for (final (type, label, value) in rows)
            if (isManagement || value == 0)
              LeaderRow(label, '$value', valueStyle: count)
            else
              Semantics(
                button: true,
                child: InkWell(
                  onTap: () => context.go(AppRoutes.pendingOfType(type.apiValue)),
                  child: LeaderRow(label, '$value', valueStyle: count),
                ),
              ),
      ],
    );
  }
}

class _Members extends StatelessWidget {
  const _Members(this.members);

  final List<MemberResult> members;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Equipo esta semana',
          trailing: TextLink(
            'Ver cumplimiento',
            onTap: () => context.go(AppRoutes.compliance),
          ),
        ),
        for (final (index, member) in members.indexed)
          _MemberRow(member, divided: index > 0),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.member, {required this.divided});

  final MemberResult member;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final (kind, text) = switch (member.compliance) {
      Compliance.passes => (MarkKind.ok, 'Cumple'),
      Compliance.fails => (MarkKind.bad, 'No cumple'),
      Compliance.pending => (MarkKind.pending, 'Pendiente'),
    };
    final note = member.note;

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: divided
            ? const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name, style: AppText.body(15, FontWeight.w600)),
                  if (note != null)
                    Text(note, style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted)),
                ],
              ),
            ),
            Text('${member.scorePercent} %', style: AppText.mono(13)),
            const SizedBox(width: 12),
            // Mismo ancho en todas las filas (crece con la letra) para que las
            // marcas queden alineadas.
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(100),
              child: Align(alignment: Alignment.centerLeft, child: StatusMark(kind, text)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bonus extends StatelessWidget {
  const _Bonus(this.summary, {required this.isManagement});

  final ControlSummary summary;
  final bool isManagement;

  @override
  Widget build(BuildContext context) {
    final bonus = summary.bonus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Bonos'),
        LeaderRow(
          isManagement ? 'A pagar si autorizas' : 'A pagar si Dirección autoriza',
          bonus.payable.format(),
          labelStyle: AppText.body(16, FontWeight.w700),
          valueStyle: AppText.mono(15, weight: FontWeight.w700, color: AppColors.violet),
        ),
        const SizedBox(height: 2),
        Text(
          _explanation(summary),
          style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35),
        ),
      ],
    );
  }

  /// Por qué una parte del premio no se paga.
  static String _explanation(ControlSummary summary) {
    final bonus = summary.bonus;
    if (bonus.prize.isZero) {
      return 'El equipo todavía no llega al 90 %: esta semana aún no hay premio.';
    }
    if (bonus.unpaid.isZero) {
      return 'Premio ${bonus.level.label.toLowerCase()}: todos cumplen.';
    }

    List<MemberResult> having(Compliance c) =>
        summary.members.where((m) => m.compliance == c).toList();
    final failing = having(Compliance.fails);
    final waiting = having(Compliance.pending);

    final reasons = [
      if (failing.isNotEmpty)
        '${_names(failing)} no ${failing.length == 1 ? 'cumplió' : 'cumplieron'} su KPI',
      if (waiting.isNotEmpty)
        '${_names(waiting)} ${waiting.length == 1 ? 'tiene' : 'tienen'} validaciones pendientes',
    ];
    final amount = bonus.unpaid.formatInline();
    if (reasons.isEmpty) return 'Sin pagar $amount.';
    return 'Sin pagar $amount: ${reasons.join(' y ')}.';
  }

  /// «Kim», «Kim y Alison», «Kim, Alison e Isaí».
  static String _names(List<MemberResult> members) {
    final names = members.map((m) => m.name).toList();
    if (names.length == 1) return names.first;
    final last = names.removeLast();
    final and = RegExp(r'^(i|hi(?![aeiouáéíóú]))', caseSensitive: false).hasMatch(last) ? 'e' : 'y';
    return '${names.join(', ')} $and $last';
  }
}
