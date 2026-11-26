import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/share/report_sharer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/async_page.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../orders/presentation/order_widgets.dart';
import '../application/control_providers.dart';
import '../domain/admin.dart';
import '../domain/payouts.dart';
import 'commissions_screen.dart';
import 'panel_widgets.dart';

/// Reportes en Excel y el historial de cambios.
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  int _pages = 1;

  /// El reporte que se está bajando.
  ReportType? _busy;

  Future<void> _download(ReportType type, String period, String filename) async {
    if (_busy != null) return;
    setState(() => _busy = type);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes =
          await ref.read(adminRepositoryProvider).downloadReport(type, period: period);
      await ref.read(reportSharerProvider).share(filename, bytes);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on PlatformException {
      messenger.showSnackBar(
        const SnackBar(content: Text('El celular no pudo abrir el archivo.')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _downloadCash(DateTime today) async {
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(2026),
      lastDate: today,
      helpText: 'Caja de qué día',
    );
    if (day == null || !mounted) return;
    final iso = '${monthKey(day)}-${day.day.toString().padLeft(2, '0')}';
    await _download(ReportType.cash, iso, 'traigo-caja-$iso.xlsx');
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider)();
    // El bono lo ven Jime y Dirección: de ahí salen el número y las fechas.
    final week = ref.watch(weekBonusProvider(null)).value;
    // El mismo mes que muestra Comisiones: el que toca liquidar.
    final month = ref.watch(commissionsViewProvider(null)).value?.data.month ??
        monthKey(today);
    final pages = [
      for (var page = 1; page <= _pages; page++) ref.watch(auditProvider(page)),
    ];
    final entries = [for (final page in pages) ...?page.value?.items];
    final first = pages.first;
    final last = pages.last;

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(auditProvider);
        ref.invalidate(weekBonusProvider);
        return ref.read(auditProvider(1).future);
      },
      children: [
        BackLink('Más', onTap: () => context.go(AppRoutes.more)),
        const PageTitle('Auditoría y reportes', size: 28),
        const SizedBox(height: 4),
        Text(
          'Todo cambio queda con quién y cuándo',
          style: AppText.body(14, FontWeight.w400, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        const SectionHeader('Reportes'),
        _ReportRow(
          title: week == null ? 'Semana' : 'Semana ${week.week.label}',
          detail: 'KPI, bonos, cierre y pagos',
          busy: _busy == ReportType.week,
          onTap: week == null
              ? null
              : () => _download(
                    ReportType.week,
                    '${week.weekNumber}',
                    'traigo-semana-${week.weekNumber}.xlsx',
                  ),
        ),
        _ReportRow(
          title: 'Caja de un día',
          detail: 'Por forma de pago, con diferencias',
          busy: _busy == ReportType.cash,
          onTap: () => _downloadCash(today),
        ),
        _ReportRow(
          title: 'Comisiones de ${monthName(month)}',
          detail: 'Por persona y por producto',
          busy: _busy == ReportType.commissions,
          onTap: () => _download(
            ReportType.commissions,
            month,
            'traigo-comisiones-$month.xlsx',
          ),
        ),
        const SizedBox(height: 14),
        const SectionHeader('Historial'),
        if (entries.isEmpty && first.isLoading)
          for (var i = 0; i < 3; i++) ...const [SizedBox(height: 8), SkeletonBlock(height: 54)]
        else if (entries.isEmpty && first.hasError)
          ErrorPanel(
            message: errorMessage(first.error!),
            onRetry: () => ref.invalidate(auditProvider),
          )
        else if (entries.isEmpty)
          const HintText('Todavía no hay cambios registrados.')
        else ...[
          for (final entry in entries) _Entry(entry, today: today),
          if (last.value?.hasMore ?? false) ...[
            const SizedBox(height: 10),
            CutButton(
              label: 'Ver más',
              height: 48,
              fontSize: 17,
              color: AppColors.ink,
              onPressed: () => setState(() => _pages++),
            ),
          ],
        ],
        const SizedBox(height: 8),
        const HintText('Los registros no se pueden editar ni borrar.'),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.title,
    required this.detail,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Excel: $title. $detail',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                color: AppColors.alt,
                child: const Icon(Icons.table_chart_outlined, size: 22, color: AppColors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(15, FontWeight.w600)),
                    Text(
                      detail,
                      style: AppText.body(12.5, FontWeight.w400, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Text(
                  'Excel',
                  style: AppText.body(
                    14.5,
                    FontWeight.w700,
                    color: onTap == null ? AppColors.muted : AppColors.violet,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _weekdays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

/// «SÁB 10:42» en la última semana; antes, «28 nov 10:42».
String _when(DateTime at, DateTime today) {
  final local = at.toLocal();
  final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
  return days >= 0 && days < 7
      ? '${_weekdays[local.weekday - 1]} ${clockTime(local)}'
      : longDate(local, today);
}

class _Entry extends StatelessWidget {
  const _Entry(this.entry, {required this.today});

  final AuditEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(_when(entry.at, today), style: AppText.mono(11.5, color: AppColors.muted)),
                Text(entry.actorName, style: AppText.body(13.5, FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 1),
            Text(entry.description, style: AppText.body(13.5, FontWeight.w400, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
