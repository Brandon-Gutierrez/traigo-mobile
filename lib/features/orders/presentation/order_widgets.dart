import 'package:flutter/material.dart';

import '../../../core/ui/ficha.dart';
import '../domain/orders.dart';

/// El estado de un pedido, con forma y texto.
class OrderStatusMark extends StatelessWidget {
  const OrderStatusMark(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final kind = switch (status) {
      OrderStatus.paid || OrderStatus.ready || OrderStatus.delivered => MarkKind.ok,
      OrderStatus.pendingPayment || OrderStatus.paymentReview => MarkKind.pending,
      OrderStatus.cancelled || OrderStatus.expired || OrderStatus.returned => MarkKind.bad,
    };
    return StatusMark(kind, status.label);
  }
}

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

const _weekdays = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
];

/// `domingo 6 dic`.
String weekdayDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

/// `11:09`, en la hora del celular.
String clockTime(DateTime at) {
  final local = at.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

int _daysAgo(DateTime at, DateTime today) {
  final local = at.toLocal();
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
}

/// En la lista: la hora si es de hoy, «Ayer» o «1 dic».
String shortDate(DateTime at, DateTime today) {
  final local = at.toLocal();
  return switch (_daysAgo(at, today)) {
    0 => clockTime(at),
    1 => 'Ayer',
    _ => '${local.day} ${_months[local.month - 1]}',
  };
}

/// En el detalle: «Hoy 11:09», «Ayer 16:20», «Mañana 10:00» o «1 dic 15:05».
String longDate(DateTime at, DateTime today) => '${dayLabel(at, today)} ${clockTime(at)}';

/// «Hoy», «Ayer», «Mañana» o «1 dic».
String dayLabel(DateTime at, DateTime today) {
  final local = at.toLocal();
  return switch (_daysAgo(at, today)) {
    0 => 'Hoy',
    1 => 'Ayer',
    -1 => 'Mañana',
    _ => '${local.day} ${_months[local.month - 1]}',
  };
}
