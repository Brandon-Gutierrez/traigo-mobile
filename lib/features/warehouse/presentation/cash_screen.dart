import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../core/money/money.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/chamfer.dart';
import '../../../core/ui/cut_button.dart';
import '../../../core/ui/error_panel.dart';
import '../../../core/ui/ficha.dart';
import '../../../core/ui/form_pieces.dart';
import '../../../core/ui/refreshable_page.dart';
import '../../../core/ui/skeleton_block.dart';
import '../../auth/presentation/auth_frame.dart' show FormError;
import '../../orders/presentation/order_widgets.dart';
import '../../team/presentation/submit_errors.dart';
import '../../team/presentation/week_widgets.dart' show OpenRow, SideNote;
import '../application/warehouse_providers.dart';
import '../domain/warehouse.dart';

/// El cierre de caja de todo el equipo: lo cobrado según los pedidos contra lo
/// recibido, para enviarlo a Jime. [date] es un día anterior; `null`, hoy.
class CashScreen extends ConsumerWidget {
  const CashScreen({super.key, this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(cashDayProvider(date));

    return RefreshablePage(
      onRefresh: () {
        ref.invalidate(cashDayProvider(date));
        return ref.read(cashDayProvider(date).future);
      },
      children: [
        if (date != null) BackLink('Caja de hoy', onTap: () => context.go(AppRoutes.cash)),
        Text('Cierre de caja', style: AppText.display(30, height: 1.1)),
        const SizedBox(height: 4),
        ...day.when(
          skipLoadingOnRefresh: true,
          data: (data) => _content(context, ref, data),
          loading: () => const [
            SizedBox(height: 8),
            SkeletonBlock(height: 110),
            SizedBox(height: 14),
            SkeletonBlock(height: 160),
          ],
          error: (error, _) => [
            const SizedBox(height: 8),
            ErrorPanel(
              message: errorMessage(error),
              onRetry: () => ref.invalidate(cashDayProvider(date)),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, CashDay day) {
    final today = ref.watch(todayProvider)();
    final isToday = date == null;
    final sentAt = day.sentAt;
    final muted = AppText.body(12.5, FontWeight.w400, color: AppColors.muted, height: 1.35);

    return [
      Text(
        '${weekdayDate(day.businessDate)} · TODO EL EQUIPO'.toUpperCase(),
        style: AppText.mono(12, color: AppColors.muted),
      ),
      const SizedBox(height: 12),
      if (day.pendingDays.isNotEmpty) ...[
        _PendingDays(day.pendingDays),
        const SizedBox(height: 12),
      ],
      _CollectedCard(day, isToday: isToday),
      if (day.status == CashStatus.observed) ...[
        const SizedBox(height: 10),
        SideNote('Jime pidió corregir: ${day.reviewNote ?? 'revisa el cierre.'}', alert: true),
      ],
      if (!day.canSend) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusMark(
            day.status == CashStatus.validated ? MarkKind.ok : MarkKind.pending,
            day.status.label,
          ),
        ),
        if (sentAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Lo envió ${day.closedByName ?? 'almacén'} · ${longDate(sentAt, today)}',
              style: muted,
            ),
          ),
      ],
      const SizedBox(height: 14),
      const SectionHeader('Por método de pago'),
      if (day.canSend)
        _ClosingForm(
          // Otro día, u observado de nuevo: formulario nuevo.
          key: ValueKey((day.businessDate, day.status)),
          day: day,
          beforeSending: _pendingSection(day),
          onSent: () {
            if (!isToday) context.go(AppRoutes.cash);
          },
        )
      else ...[
        _SentLines(day),
        ..._pendingSection(day),
      ],
      const SizedBox(height: 10),
      Text('Jime valida el cierre; cuenta para tu KPI «Cierre de caja diaria».', style: muted),
    ];
  }
}

List<Widget> _pendingSection(CashDay day) => [
      if (day.pending.isNotEmpty) ...[
        const SizedBox(height: 14),
        const SectionHeader('Pendiente de cobro'),
        for (final pending in day.pending) _Pending(pending),
      ],
    ];

class _PendingDays extends StatelessWidget {
  const _PendingDays(this.days);

  final List<PendingDay> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          days.length == 1 ? '1 día por cerrar' : '${days.length} días por cerrar',
        ),
        for (final pending in days)
          OpenRow(
            onTap: () => context.go(AppRoutes.cashDay(pending.date)),
            children: [
              Text(
                _capitalized(weekdayDate(pending.date)),
                style: AppText.body(15, FontWeight.w600),
              ),
              const SizedBox(height: 2),
              StatusMark(
                pending.status == CashStatus.observed ? MarkKind.bad : MarkKind.pending,
                pending.status.label,
              ),
            ],
          ),
      ],
    );
  }

  static String _capitalized(String text) =>
      '${text[0].toUpperCase()}${text.substring(1)}';
}

class _CollectedCard extends StatelessWidget {
  const _CollectedCard(this.day, {required this.isToday});

  final CashDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final paid = day.paidOrders == 1 ? '1 pedido cobrado' : '${day.paidOrders} pedidos cobrados';
    return SizedBox(
      width: double.infinity,
      child: ChamferBox(
        color: AppColors.cyan,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (isToday ? 'Cobrado hoy según pedidos' : 'Cobrado ese día según pedidos')
                  .toUpperCase(),
              style: AppText.label(color: AppColors.ink),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                day.collected.format(),
                textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
                style: AppText.display(40, weight: FontWeight.w800, height: 1.1),
              ),
            ),
            Text(
              day.pendingOrders == 0 ? paid : '$paid · ${day.pendingOrders} por cobrar',
              style: AppText.body(13.5, FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// Método · Pedidos (según el sistema) · Recibido.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.method, required this.expected, required this.received, this.mark});

  final String method;
  final Widget expected;
  final Widget received;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final mark = this.mark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.rule, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method, style: AppText.body(15, FontWeight.w600)),
                if (mark != null) ...[const SizedBox(height: 2), mark],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: expected,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 9, child: received),
        ],
      ),
    );
  }
}

Widget _header() => Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Expanded(flex: 11, child: Text('MÉTODO', style: AppText.label())),
          const SizedBox(width: 6),
          Expanded(
            flex: 7,
            child: Text('PEDIDOS', textAlign: TextAlign.right, style: AppText.label()),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: Text('RECIBIDO', textAlign: TextAlign.right, style: AppText.label()),
          ),
        ],
      ),
    );

Widget _mark(Money difference) => StatusMark(
      difference.isZero ? MarkKind.ok : MarkKind.bad,
      difference.isZero ? 'Cuadra' : 'Diferencia',
    );

/// `+Bs 20`, `−Bs 50` o `Bs 0`.
String _signed(Money difference) =>
    '${difference > Money.zero ? '+' : ''}${difference.format()}';

/// `null` mientras falte algún monto.
Widget _totalDifference(Money? difference) => Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Diferencia del día', style: AppText.body(15, FontWeight.w700)),
          ),
          Text(
            difference == null ? '—' : _signed(difference),
            style: AppText.mono(
              15,
              weight: FontWeight.w700,
              color: difference == null || difference.isZero ? AppColors.ink : AppColors.alert,
            ),
          ),
        ],
      ),
    );

class _SentLines extends StatelessWidget {
  const _SentLines(this.day);

  final CashDay day;

  @override
  Widget build(BuildContext context) {
    final note = day.note;
    final difference = day.lines.fold(Money.zero, (sum, l) => sum + (l.difference ?? Money.zero));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        for (final line in day.lines)
          _LineRow(
            method: line.method.label,
            mark: line.difference == null ? null : _mark(line.difference!),
            expected: Text(line.expected.format(symbol: false), style: AppText.mono(13.5)),
            received: Text(
              line.counted?.format(symbol: false) ?? '—',
              textAlign: TextAlign.right,
              style: AppText.mono(13.5, weight: FontWeight.w700),
            ),
          ),
        _totalDifference(difference),
        if (note != null) ...[
          const SizedBox(height: 8),
          SideNote('Explicación: $note'),
        ],
      ],
    );
  }
}

class _ClosingForm extends ConsumerStatefulWidget {
  const _ClosingForm({
    super.key,
    required this.day,
    required this.beforeSending,
    required this.onSent,
  });

  final CashDay day;

  /// Lo que va entre la tabla y la explicación (lo pendiente de cobro).
  final List<Widget> beforeSending;
  final VoidCallback onSent;

  @override
  ConsumerState<_ClosingForm> createState() => _ClosingFormState();
}

class _ClosingFormState extends ConsumerState<_ClosingForm> {
  String _requestKey = const Uuid().v4();

  /// Lo contado por forma de pago. Se escribe lo que llegó de verdad: no se
  /// rellena con lo que dice el sistema (solo el cero cuando no hubo cobros).
  late final Map<PaymentMethod, TextEditingController> _counted = {
    for (final line in widget.day.lines)
      line.method: TextEditingController(text: _initialText(line)),
  };

  /// Las formas de pago que la persona ya escribió.
  final Set<PaymentMethod> _typed = {};
  late final _note = TextEditingController(
    text: widget.day.status == CashStatus.observed ? widget.day.note : null,
  );
  bool _busy = false;
  String? _error;

  static String _initialText(CashLine line) =>
      line.counted?.format(symbol: false) ?? (line.expected.isZero ? '0' : '');

  @override
  void didUpdateWidget(_ClosingForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al actualizar pueden llegar cobros: aparece una forma de pago nueva o
    // el cero que se puso solo deja de valer.
    for (final line in widget.day.lines) {
      final controller = _counted[line.method];
      if (controller == null) {
        _counted[line.method] = TextEditingController(text: _initialText(line));
      } else if (!_typed.contains(line.method) && line.counted == null) {
        controller.text = _initialText(line);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _counted.values) {
      controller.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _edit() => setState(() {
        _requestKey = const Uuid().v4();
        _error = null;
      });

  Money? _amount(PaymentMethod method) => Money.tryParseInput(_counted[method]!.text);

  /// La diferencia del día, o `null` mientras falte algún monto.
  Money? get _difference {
    var total = Money.zero;
    for (final line in widget.day.lines) {
      final counted = _amount(line.method);
      if (counted == null) return null;
      total = total + (counted - line.expected);
    }
    return total;
  }

  bool get _balanced => widget.day.lines.every((l) => _amount(l.method) == l.expected);

  /// Alguna forma de pago ya escrita no cuadra (aunque el total sí).
  bool get _hasDifference => widget.day.lines.any((l) {
        final counted = _amount(l.method);
        return counted != null && counted != l.expected;
      });

  String? get _blockedReason {
    for (final line in widget.day.lines) {
      final text = _counted[line.method]!.text;
      if (text.trim().isEmpty) return 'Falta lo recibido';
      if (Money.tryParseInput(text) == null) return 'Revisa los montos';
    }
    if (!_balanced && _note.text.trim().isEmpty) return 'Explica la diferencia';
    return null;
  }

  Future<bool> _confirm() async {
    final day = widget.day;
    final received = day.lines.fold(Money.zero, (sum, l) => sum + _amount(l.method)!);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Enviar el cierre del ${weekdayDate(day.businessDate)}?'),
        scrollable: true,
        content: Text(
          'Según los pedidos: ${day.collected.formatInline()}. '
          'Recibido: ${received.formatInline()}.\n\n'
          'Después solo se puede cambiar si Jime lo observa.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!await _confirm() || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final note = _note.text.trim();
      await ref.read(warehouseRepositoryProvider).sendClosing(NewCashClosing(
            clientUuid: _requestKey,
            businessDate: widget.day.businessDate,
            counted: {for (final l in widget.day.lines) l.method: _amount(l.method)!},
            note: note.isEmpty ? null : note,
          ));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Cierre enviado a Jime.')));
      refreshWarehouseData(ref);
      widget.onSent();
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _error = submitErrorMessage(e));
      if (e is ConflictException) refreshWarehouseData(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedReason;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        for (final line in widget.day.lines)
          _LineRow(
            method: line.method.label,
            mark: _amount(line.method) == null
                ? null
                : _mark(_amount(line.method)! - line.expected),
            expected: Text(line.expected.format(symbol: false), style: AppText.mono(13.5)),
            received: Semantics(
              key: ValueKey('cash-${line.method.apiValue}'),
              label: 'Recibido por ${line.method.label}',
              child: TextField(
                controller: _counted[line.method],
                enabled: !_busy,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(12),
                ],
                style: AppText.mono(15, weight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  hintText: '¿Cuánto?',
                  hintStyle: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
                onChanged: (_) {
                  _typed.add(line.method);
                  _edit();
                },
              ),
            ),
          ),
        _totalDifference(_difference),
        ...widget.beforeSending,
        const SizedBox(height: 12),
        LabeledField(
          label: _hasDifference ? 'Explica la diferencia' : 'Nota (opcional)',
          controller: _note,
          lines: 2,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(500)],
          onChanged: (_) => _edit(),
        ),
        if (error != null) ...[const SizedBox(height: 10), FormError(error)],
        const SizedBox(height: 12),
        CutButton(
          label: _busy ? 'Enviando…' : (blocked ?? 'Enviar cierre a Jime'),
          onPressed: blocked == null ? _send : null,
          busy: _busy,
        ),
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending(this.pending);

  final PendingCollection pending;

  @override
  Widget build(BuildContext context) {
    final seller = pending.sellerName;
    final detail = pending.detail;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (seller == null ? pending.number : '${pending.number} · $seller')
                      .toUpperCase(),
                  style: AppText.mono(11.5, color: AppColors.muted),
                ),
                Text(pending.customerName, style: AppText.body(15, FontWeight.w600)),
                Text(
                  detail == null ? pending.method.label : '${pending.method.label} · $detail',
                  style: AppText.body(13, FontWeight.w400, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(pending.total.format(), style: AppText.display(17)),
        ],
      ),
    );
  }
}
