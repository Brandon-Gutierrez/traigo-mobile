/// La tabla de la caja (Método · Pedidos · Recibido), que ven Isaí al enviar
/// y Jime al validar.
library;

import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ficha.dart';
import '../../team/presentation/week_widgets.dart' show SideNote;
import '../domain/warehouse.dart';

/// Método · Pedidos (según el sistema) · Recibido.
class CashLineRow extends StatelessWidget {
  const CashLineRow({super.key, required this.method, required this.expected, required this.received, this.mark});

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

Widget cashTableHeader() => Padding(
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

Widget cashMark(Money difference) => StatusMark(
      difference.isZero ? MarkKind.ok : MarkKind.bad,
      difference.isZero ? 'Cuadra' : 'Diferencia',
    );

/// `+Bs 20`, `−Bs 50` o `Bs 0`.
String _signed(Money difference) =>
    '${difference > Money.zero ? '+' : ''}${difference.format()}';

/// `null` mientras falte algún monto.
Widget cashDifferenceRow(Money? difference) => Container(
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

class SentCashLines extends StatelessWidget {
  const SentCashLines(this.day, {super.key});

  final CashDay day;

  @override
  Widget build(BuildContext context) {
    final note = day.note;
    final difference = day.lines.fold(Money.zero, (sum, l) => sum + (l.difference ?? Money.zero));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cashTableHeader(),
        for (final line in day.lines)
          CashLineRow(
            method: line.method.label,
            mark: line.difference == null ? null : cashMark(line.difference!),
            expected: Text(line.expected.format(symbol: false), style: AppText.mono(13.5)),
            received: Text(
              line.counted?.format(symbol: false) ?? '—',
              textAlign: TextAlign.right,
              style: AppText.mono(13.5, weight: FontWeight.w700),
            ),
          ),
        cashDifferenceRow(difference),
        if (note != null) ...[
          const SizedBox(height: 8),
          SideNote('Explicación: $note'),
        ],
      ],
    );
  }
}

class PendingCollectionRow extends StatelessWidget {
  const PendingCollectionRow(this.pending, {super.key});

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

/// Lo que todavía no se cobró ese día.
List<Widget> pendingCollections(CashDay day) => [
      if (day.pending.isNotEmpty) ...[
        const SizedBox(height: 14),
        const SectionHeader('Pendiente de cobro'),
        for (final pending in day.pending) PendingCollectionRow(pending),
      ],
    ];
