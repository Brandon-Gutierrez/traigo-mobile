/// «Por autorizar»: lo que Dirección aprueba o devuelve.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/dialogs.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../control/application/control_providers.dart';
import '../../control/presentation/panel_widgets.dart';
import '../../team/presentation/week_widgets.dart' show OpenRow, SideNote;
import '../domain/authorizations.dart';

class AuthorizationsScreen extends StatelessWidget {
  const AuthorizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: authorizationsProvider,
      header: const [
        PageTitle('Por autorizar', subtitle: 'Dirección · nadie aprueba lo propio'),
        SizedBox(height: 10),
      ],
      builder: (context, ref, items) {
        final now = ref.watch(nowProvider)();
        return [
          if (items.isEmpty)
            Text(
              'No hay nada esperando tu autorización.',
              style: AppText.body(15, FontWeight.w400, color: AppColors.muted),
            ),
          for (final item in items)
            OpenRow(
              onTap: () =>
                  context.go(AppRoutes.authorization(item.type.apiValue, item.id)),
              children: [
                Text(
                  item.type.label.toUpperCase(),
                  style: AppText.mono(11, weight: FontWeight.w700, color: AppColors.violet),
                ),
                Text(item.title, style: AppText.body(15.5, FontWeight.w600, height: 1.2)),
                Text(
                  [
                    'Lo envió ${item.requestedBy} ${timeAgo(item.requestedAt, now)}',
                    if (item.amount != null) item.amount!.formatInline(),
                  ].join(' · '),
                  style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            ),
        ];
      },
    );
  }
}

class AuthorizationScreen extends StatelessWidget {
  const AuthorizationScreen({super.key, required this.type, required this.id});

  final AuthorizationType type;
  final String id;

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      provider: authorizationProvider((type: type, id: id)),
      header: [BackLink('Por autorizar', onTap: () => context.go(AppRoutes.approve))],
      builder: (context, ref, detail) => [_Detail(detail)],
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail(this.detail);

  final AuthorizationDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = detail.item;
    final now = ref.watch(nowProvider)();
    final amount = item.amount;
    final isPayment = amount != null;
    final approveLabel = switch (item.type) {
      AuthorizationType.weeklyBonus || AuthorizationType.commissions => 'Autorizar pago',
      AuthorizationType.priceChange => 'Aprobar el cambio',
      AuthorizationType.promotion => 'Aprobar la promoción',
    };

    Future<bool> askApproval() => confirmAction(
          context,
          title: '¿$approveLabel?',
          body: switch (item.type) {
            AuthorizationType.weeklyBonus =>
              'La semana queda cerrada: ya no se cambian los resultados.',
            AuthorizationType.commissions => 'Jime podrá marcarlas como pagadas.',
            AuthorizationType.priceChange => 'El precio nuevo se aplica enseguida.',
            AuthorizationType.promotion => 'La promoción se podrá publicar.',
          },
          action: 'Autorizar',
        );

    Future<void> approve() async {
      if (!context.mounted) return;
      final done = await runPanelAction(
        context,
        () => ref.read(managementRepositoryProvider).approve(item.type, item.id),
        success: 'Autorizado.',
      );
      if (done && context.mounted) context.go(AppRoutes.approve);
    }

    Future<void> sendBack() async {
      final reason = await askReason(
        context,
        title: '¿Devolver a Jime?',
        label: 'Motivo',
        action: 'Devolver',
        destructive: true,
      );
      if (reason == null || !context.mounted) return;
      final done = await runPanelAction(
        context,
        () => ref
            .read(managementRepositoryProvider)
            .sendBack(item.type, item.id, reason: reason),
        success: 'Devuelto a Jime.',
      );
      if (done && context.mounted) context.go(AppRoutes.approve);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChamferBox(
          color: AppColors.cyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title.toUpperCase(), style: AppText.label(color: AppColors.ink)),
              if (isPayment)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(amount.format(),
                      style: AppText.display(40, weight: FontWeight.w800, height: 1.1)),
                )
              else
                Text(item.type.label, style: AppText.display(22)),
              Text(
                [
                  if (detail.pays.isNotEmpty)
                    'a ${detail.pays.length} ${detail.pays.length == 1 ? 'persona' : 'personas'}',
                  '${detail.pays.isEmpty ? 'Lo' : 'lo'} envió ${item.requestedBy} '
                      '${timeAgo(item.requestedAt, now)}',
                ].join(' · '),
                style: AppText.body(13.5, FontWeight.w400),
              ),
            ],
          ),
        ),
        if (detail.pays.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader('Se paga'),
          for (final line in detail.pays) LeaderRow(line.name, line.amount.format()),
        ],
        if (detail.unpaid.isNotEmpty) ...[
          const SizedBox(height: 10),
          const SectionHeader('No se paga'),
          for (final line in detail.unpaid) ...[
            LeaderRow(
              line.name,
              line.amount.format(),
              labelStyle: AppText.body(15, FontWeight.w600),
            ),
            if (line.reason != null) HintText(line.reason!),
          ],
        ],
        if (detail.changes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionHeader('Qué cambia'),
          for (final change in detail.changes)
            LeaderRow(
              change.label,
              change.before == null ? change.after : '${change.before} → ${change.after}',
              valueStyle: AppText.mono(14, weight: FontWeight.w700),
            ),
        ],
        if (detail.checks.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionHeader(
            item.type == AuthorizationType.weeklyBonus ? 'Controles de Jime' : 'Ten en cuenta',
          ),
          for (final check in detail.checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(check, style: AppText.body(14, FontWeight.w400, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
        if (detail.blockedReason != null) ...[
          const SizedBox(height: 10),
          SideNote(detail.blockedReason!, alert: true),
        ],
        const SizedBox(height: 14),
        ActionButton(
          label: approveLabel,
          confirm: askApproval,
          onPressed: detail.canApprove ? approve : null,
        ),
        Center(child: TextLink('Devolver a Jime', color: AppColors.ink, onTap: sendBack)),
      ],
    );
  }
}
