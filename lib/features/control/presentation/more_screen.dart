import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth.dart';
import '../../auth/presentation/account_header.dart';
import '../../orders/presentation/order_widgets.dart';
import '../../team/domain/my_week.dart';
import '../application/control_providers.dart';
import '../domain/admin.dart';
import 'panel_widgets.dart';

/// «Más»: lo que no tiene pestaña. Cada rol ve lo que puede hacer.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(sessionControllerProvider).value?.member;
    if (member == null) return const SizedBox.shrink();
    final control = member.role == MemberRole.control;

    return RefreshablePage(
      onRefresh: () async {
        if (!control) return;
        ref.invalidate(systemStatusProvider);
        ref.invalidate(controlDeliverablesProvider);
        await ref.read(systemStatusProvider.future);
      },
      children: [
        const PageTitle('Más'),
        const SizedBox(height: 4),
        Text(
          control ? 'Control y validación' : 'Dirección',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        MenuRow(
          icon: Icons.location_on_outlined,
          title: 'Asistencia',
          subtitle: 'Tus entradas y salidas',
          onTap: () => context.push(AppRoutes.attendance),
        ),
        if (!control)
          MenuRow(
            icon: Icons.checklist,
            title: 'Cumplimiento',
            subtitle: 'El KPI de cada integrante esta semana',
            onTap: () => context.go(AppRoutes.compliance),
          ),
        MenuRow(
          icon: Icons.sell_outlined,
          title: 'Precios autorizados',
          subtitle: 'Minorista, mayorista, mínimo y comisión',
          onTap: () => context.go(AppRoutes.morePrices),
        ),
        if (control) ...[
          MenuRow(
            icon: Icons.monetization_on_outlined,
            title: 'Comisiones',
            subtitle: 'Liquidación mensual por persona',
            onTap: () => context.go(AppRoutes.moreCommissions),
          ),
          MenuRow(
            icon: Icons.receipt_long_outlined,
            title: 'Pedidos',
            subtitle: 'Devoluciones y duplicados',
            onTap: () => context.go(AppRoutes.moreOrders),
          ),
          _DeliverablesRow(onTap: () => context.go(AppRoutes.moreDeliverables)),
          MenuRow(
            icon: Icons.inventory_2_outlined,
            title: 'Inventario y conteos',
            subtitle: 'Exactitud física contra el sistema',
            onTap: () => context.go(AppRoutes.moreCounts),
          ),
        ],
        MenuRow(
          icon: Icons.shield_outlined,
          title: 'Auditoría y reportes',
          subtitle: 'Historial y exportar a Excel',
          onTap: () => context.go(AppRoutes.moreAudit),
        ),
        if (control) ...[
          MenuRow(
            icon: Icons.key_outlined,
            title: 'Accesos del equipo',
            subtitle: 'PIN nuevo y cerrar sesiones',
            onTap: () => context.go(AppRoutes.moreAccess),
          ),
          const _BackupRow(),
        ],
        MenuRow(
          icon: Icons.logout,
          title: 'Cerrar sesión',
          subtitle: 'Pide el código de verificación al volver a entrar',
          onTap: () => confirmLogout(context, ref),
        ),
      ],
    );
  }
}

class _DeliverablesRow extends ConsumerWidget {
  const _DeliverablesRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliverables = ref.watch(controlDeliverablesProvider).value;
    final waiting =
        deliverables?.where((d) => d.status == DeliverableStatus.inReview).length ?? 0;
    return MenuRow(
      icon: Icons.widgets_outlined,
      title: 'Entregas de Sistemas',
      subtitle: waiting == 0
          ? '8 obligatorias para el primer bono'
          : '$waiting por validar',
      onTap: onTap,
    );
  }
}

class _BackupRow extends ConsumerWidget {
  const _BackupRow();

  static String _describe(SystemStatus status, DateTime today) {
    final backup = status.lastBackupAt;
    final tested = status.restoreTestedAt;
    final parts = [
      backup == null ? 'Sin copia todavía' : 'Última copia ${longDate(backup, today).toLowerCase()}',
      tested == null
          ? 'restauración sin probar'
          : 'restauración probada ${dayLabel(tested, today).toLowerCase()}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(systemStatusProvider);
    final today = ref.watch(todayProvider)();
    return MenuRow(
      icon: Icons.cloud_outlined,
      title: 'Respaldo',
      subtitle: status.when(
        data: (data) => _describe(data, today),
        loading: () => 'Consultando…',
        error: (_, _) => 'No se pudo consultar',
      ),
    );
  }
}
