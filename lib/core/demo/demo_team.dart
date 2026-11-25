/// KPI, evidencia y entregas de Sistemas de la demo.
///
/// Indicadores, metas (las de cantidad, al 90 % por ser la primera semana),
/// pesos, mínimos, reparto, entregas y semanas salen del Excel. Los valores
/// reales, la evidencia y lo que Jime validó son de ejemplo.
library;

import '../../features/auth/domain/auth.dart';
import '../../features/home/domain/home.dart';
import '../../features/orders/domain/orders.dart';
import '../../features/team/domain/bonus.dart';
import '../../features/team/domain/kpi.dart';
import '../../features/team/domain/my_week.dart';
import '../../features/team/domain/team_week.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import 'demo_backend.dart';
import 'demo_sales.dart';

class DemoTeam {
  DemoTeam({required this._now, required this._sales}) {
    for (final MapEntry(key: memberId, value: profile) in _profiles.entries) {
      for (final (index, kpi) in profile.kpis.indexed) {
        final id = '$memberId-${index + 1}';
        _evidence[id] = _seedEvidence(id, kpi.evidence);
      }
    }
  }

  final DateTime Function() _now;
  final DemoSales _sales;

  /// Por resultado semanal, lo más nuevo primero.
  final Map<String, List<Evidence>> _evidence = {};
  late final Map<String, List<Deliverable>> _deliverables = _seedDeliverables();

  /// Envíos ya recibidos, por su clave contra duplicados.
  final Map<String, Evidence> _sentEvidence = {};
  final Map<String, Deliverable> _sentDeliverables = {};
  int _nextEvidence = 1;

  double shareRate(String memberId) => _profile(memberId).shareRate;

  Money? monthCommission(String memberId) {
    final amount = _profile(memberId).monthCommission;
    return amount == null ? null : Money.parse(amount);
  }

  MyKpi kpiOf(String memberId) {
    final profile = _profile(memberId);
    final indicators = [for (final i in _indicators(memberId)) i.indicator];
    final deliverables = _deliverables[memberId];
    final progress = deliverables == null
        ? null
        : DeliverableProgress(
            approved: deliverables.where((d) => d.status == DeliverableStatus.onTime).length,
            total: deliverables.length,
          );
    return MyKpi(
      scorePercent: KpiRules.scorePercent(indicators),
      minimumPercent: profile.minimumPercent,
      compliance: KpiRules.compliance(
        indicators,
        minimumPercent: profile.minimumPercent,
        deliverablesApproved: progress?.complete ?? true,
      ),
      indicators: indicators,
      deliverables: progress,
    );
  }

  MyWeek myWeek(Member member, {int? weekNumber}) {
    _requireTeam(member);
    if (weekNumber != null && weekNumber != 1) {
      throw const NotFoundException('En la demo solo está la primera semana.');
    }
    final kpi = kpiOf(member.id);
    final complete = kpi.indicators.every((i) => i.actual != null);
    return MyWeek(
      week: DemoBackend.week,
      weekNumber: 1,
      countTargetFactor: 0.9,
      scorePercent: complete ? kpi.scorePercent : null,
      partialScorePercent: kpi.scorePercent,
      minimumPercent: kpi.minimumPercent,
      compliance: kpi.compliance,
      indicators: _indicators(member.id),
      deliverables: List.unmodifiable(_deliverables[member.id] ?? const []),
      acceptsEvidence: true,
    );
  }

  TeamWeek teamWeek(Member member) {
    _requireTeam(member);
    final week = DemoBackend.week;
    final share = shareRate(member.id);
    final kpi = kpiOf(member.id);
    return TeamWeek(
      week: week,
      collected: DemoBackend.collected,
      tiers: [
        for (final level in [BonusLevel.partial, BonusLevel.complete, BonusLevel.superior])
          TierRow(
            tier: level,
            thresholdPercent: level.fromPercent,
            salesNeeded: BonusRules.threshold(week.target, level),
            fund: BonusRules.prizeAt(week.basePrize, level),
            myShare: BonusRules.prizeAt(week.basePrize, level).percent(share),
          ),
      ],
      myShareRate: share,
      myMinimumPercent: kpi.minimumPercent,
      myPartialScorePercent: kpi.scorePercent,
      myCompliance: kpi.compliance,
      weeks: [
        for (final (index, (label, start, end, target, prize)) in _campaign.indexed)
          CampaignWeek(
            number: index + 1,
            week: BonusWeek(
              label: label,
              startsOn: start,
              endsOn: end,
              target: Money.parse(target),
              basePrize: Money.parse(prize),
            ),
            isCurrent: index == 0,
          ),
      ],
    );
  }

  Evidence submitEvidence(Member member, String resultId, NewEvidence evidence) {
    _requireTeam(member);
    final repeated = _sentEvidence[evidence.clientUuid];
    if (repeated != null) return repeated;

    final indicator = _indicators(member.id).where((i) => i.indicator.id == resultId);
    if (indicator.isEmpty) {
      throw const NotFoundException('No encontramos ese indicador entre los tuyos.');
    }
    if (indicator.single.isValidated) {
      throw const ConflictException(
        code: 'evidence_validated',
        message: 'Jime ya validó este indicador.',
      );
    }

    String? url;
    String? orderId;
    String? orderNumber;
    switch (evidence.kind) {
      case EvidenceKind.photo:
        url = evidence.file!.path;
      case EvidenceKind.link:
        url = normalizeLink(evidence.url!);
        if (url == null) {
          throw const ValidationException(message: 'El enlace no es válido.');
        }
      case EvidenceKind.order:
        if (!member.role.canSell) {
          throw const ValidationException(message: 'Solo quienes venden adjuntan pedidos.');
        }
        final order = _sales.order(member, evidence.orderId!).summary;
        if (const {OrderStatus.cancelled, OrderStatus.expired, OrderStatus.returned}
            .contains(order.status)) {
          throw const ValidationException(message: 'Ese pedido está anulado.');
        }
        orderId = order.id;
        orderNumber = order.number;
    }

    final saved = Evidence(
      id: 'ev-demo-${_nextEvidence++}',
      kind: evidence.kind,
      status: EvidenceStatus.inReview,
      submittedAt: _now(),
      url: url,
      orderId: orderId,
      orderNumber: orderNumber,
      note: evidence.note,
    );
    _evidence[resultId]!.insert(0, saved);
    _sentEvidence[evidence.clientUuid] = saved;
    return saved;
  }

  Deliverable submitDeliverable(
    Member member,
    String id, {
    required DateTime deliveredOn,
    required String clientUuid,
    UploadFile? file,
    String? url,
  }) {
    _requireTeam(member);
    final repeated = _sentDeliverables[clientUuid];
    if (repeated != null) return repeated;

    final list = _deliverables[member.id] ?? const <Deliverable>[];
    final index = list.indexWhere((d) => d.id == id);
    if (index < 0) {
      throw const NotFoundException('No encontramos esa entrega entre las tuyas.');
    }
    final current = list[index];
    if (current.isValidated) {
      throw const ConflictException(
        code: 'deliverable_validated',
        message: 'Jime ya validó esta entrega.',
      );
    }
    if (deliveredOn.isAfter(DemoBackend.today)) {
      throw const ValidationException(message: 'La fecha real no puede ser futura.');
    }
    final link = url == null ? null : normalizeLink(url);
    if (file == null && link == null) {
      throw const ValidationException(message: 'Adjunta una foto o un enlace.');
    }

    final saved = Deliverable(
      id: current.id,
      title: current.title,
      acceptanceTest: current.acceptanceTest,
      dueOn: current.dueOn,
      status: DeliverableStatus.inReview,
      memberId: current.memberId,
      memberName: current.memberName,
      deliveredOn: deliveredOn,
      evidenceUrl: file?.path ?? link,
    );
    _deliverables[member.id]![index] = saved;
    _sentDeliverables[clientUuid] = saved;
    return saved;
  }

  /// Entregas enviadas que Jime todavía no valida.
  int get deliverablesInReview => _deliverables.values
      .expand((list) => list)
      .where((d) => d.status == DeliverableStatus.inReview)
      .length;

  List<WeekIndicator> _indicators(String memberId) => [
        for (final (index, kpi) in _profile(memberId).kpis.indexed)
          _indicator('$memberId-${index + 1}', kpi),
      ];

  WeekIndicator _indicator(String id, _Kpi kpi) {
    final evidence = _evidence[id]!;
    return WeekIndicator(
      indicator: KpiIndicator(
        id: id,
        name: kpi.name,
        target: kpi.target,
        actual: kpi.actual,
        weight: kpi.weight,
        // El estado del indicador es el de la evidencia más reciente.
        evidence: evidence.isEmpty ? EvidenceStatus.missing : evidence.first.status,
      ),
      howVerified: kpi.howVerified,
      unit: kpi.unit,
      evidence: List.unmodifiable(evidence),
    );
  }

  _Profile _profile(String memberId) => _profiles[memberId]!;

  static void _requireTeam(Member member) {
    if (member.role.isControlSide) {
      throw const NotFoundException('Esto es para el equipo.');
    }
  }
}

// ──────────────────────────────────────────── datos de la primera semana

DateTime _dec(int day, int hour, int minute) => DateTime(2026, 12, day, hour, minute);

enum _Seed { validated, missing, observedFicha, livesInReview, registroInReview, paidOrder }

List<Evidence> _seedEvidence(String resultId, _Seed seed) {
  Evidence link(String id, EvidenceStatus status, DateTime at, String url, {String? reviewNote}) =>
      Evidence(
        id: id,
        kind: EvidenceKind.link,
        status: status,
        submittedAt: at,
        url: url,
        reviewNote: reviewNote,
      );

  return switch (seed) {
    _Seed.missing => [],
    _Seed.validated => [
        link('ev-$resultId', EvidenceStatus.validated, _dec(4, 18, 0),
            'https://example.com/evidencia/$resultId'),
      ],
    _Seed.observedFicha => [
        link('ev-$resultId', EvidenceStatus.observed, _dec(5, 17, 10),
            'https://example.com/fichas-1-6dic',
            reviewNote: 'Una de las fichas no tiene el precio autorizado.'),
      ],
    _Seed.livesInReview => [
        for (var n = 3; n >= 1; n--)
          link('ev-$resultId-$n', EvidenceStatus.inReview, _dec(6, 9, 10 + n),
              'https://example.com/live-$n'),
      ],
    _Seed.registroInReview => [
        Evidence(
          id: 'ev-$resultId',
          kind: EvidenceKind.photo,
          status: EvidenceStatus.inReview,
          submittedAt: _dec(6, 9, 40),
          url: 'demo://fotos/registro-ventas-1-6dic.jpg',
          note: 'Incluye las 4 ventas cobradas.',
        ),
      ],
    _Seed.paidOrder => [
        Evidence(
          id: 'ev-$resultId',
          kind: EvidenceKind.order,
          status: EvidenceStatus.validated,
          submittedAt: _dec(5, 19, 30),
          orderId: '1040',
          orderNumber: 'N-1040',
        ),
      ],
  };
}

Map<String, List<Deliverable>> _seedDeliverables() {
  Deliverable item(
    int n,
    String memberId,
    String title,
    String test,
    int dueDay, {
    DeliverableStatus status = DeliverableStatus.pending,
    int? deliveredDay,
  }) =>
      Deliverable(
        id: 'd-$n',
        title: title,
        acceptanceTest: test,
        dueOn: DateTime(2026, 11, dueDay),
        status: status,
        memberId: memberId,
        memberName: memberId == '6' ? 'Sistemas 1' : 'Sistemas 2',
        deliveredOn: deliveredDay == null ? null : DateTime(2026, 11, deliveredDay),
        evidenceUrl: deliveredDay == null ? null : 'https://example.com/entrega-$n',
      );

  const onTime = DeliverableStatus.onTime;
  return {
    '6': [
      item(1, '6', 'Tienda web publicada, navegable y con catálogo',
          'Acceso público; categorías, precios y ficha de producto', 30,
          status: onTime, deliveredDay: 30),
      item(2, '6', 'Compra en línea probada de principio a fin',
          'Compra real o autorizada, pago confirmado, pedido y aviso', 30,
          status: DeliverableStatus.inReview, deliveredDay: 30),
      item(3, '6', 'Pedidos web integrados al control de Jime',
          'Pedido pagado en web: mismo ID, monto, cliente, SKU y stock en el panel central', 30),
      item(4, '6', 'Seguridad del checkout y permisos de consulta',
          'HTTPS; pago en pasarela; sin datos de tarjeta en TRAIGO; acceso probado por rol', 30,
          status: onTime, deliveredDay: 29),
    ],
    '7': [
      item(5, '7', 'Sistema de inventarios y ventas en funcionamiento',
          'Alta de SKU; stock, pedido, despacho y movimiento trazable', 29,
          status: onTime, deliveredDay: 29),
      item(6, '7', 'Asignación automática de comisiones probada',
          'Prueba de venta con vendedor, margen, % y comisión correcta', 29,
          status: onTime, deliveredDay: 29),
      item(7, '7', 'Comisiones mensuales + KPI + bonos semanales automatizados',
          'Dos ventas de prueba, 2 KPI distintos, bono 100%/115%, devolución y bloqueo al no cumplir',
          29, status: onTime, deliveredDay: 28),
      item(8, '7', 'Panel de Jime, auditoría y respaldo restaurable',
          'Jime ve y valida; aprobación Dirección; historial de cambios, roles y restauración probados',
          29, status: onTime, deliveredDay: 29),
    ],
  };
}

class _Kpi {
  const _Kpi(
    this.name,
    this.howVerified,
    this.target,
    this.actual,
    this.weight, {
    this.unit = KpiUnit.count,
    this.evidence = _Seed.validated,
  });

  final String name;
  final String howVerified;
  final double target;
  final double actual;
  final double weight;
  final KpiUnit unit;
  final _Seed evidence;
}

class _Profile {
  const _Profile({
    required this.shareRate,
    required this.minimumPercent,
    required this.kpis,
    this.monthCommission,
  });

  final double shareRate;
  final int minimumPercent;
  final List<_Kpi> kpis;
  final String? monthCommission;
}

const _percent = KpiUnit.percent;

const _profiles = <String, _Profile>{
  '2': _Profile(shareRate: 0.20, minimumPercent: 90, kpis: [
    _Kpi('Videos cortos publicados', 'Videos publicados en cuentas de TRAIGO', 9, 9, 0.25),
    _Kpi('Historias y estados publicados', 'Historias/estados con producto, novedad o usos.', 17, 17, 0.10),
    _Kpi('Artes o fichas comerciales terminados', 'Diseños aprobados, con precios autorizados', 6, 5, 0.15,
        evidence: _Seed.observedFicha),
    _Kpi('LIVES realizados', 'Transmisiones comerciales realizadas', 3, 3, 0.20,
        evidence: _Seed.livesInReview),
    _Kpi('Consultas calificadas generadas',
        'Cliente identificado + producto de interés + medio de contacto', 15, 12, 0.20),
    _Kpi('Informe semanal entregado', 'Con resultados(métricas), enlaces y próximas acciones', 1, 1, 0.10),
  ]),
  '3': _Profile(shareRate: 0.20, minimumPercent: 90, kpis: [
    _Kpi('Exactitud del inventario', 'Porcentaje de coincidencia entre físico y sistema', 98, 98, 0.20,
        unit: _percent),
    _Kpi('Despachos dentro de plazo', 'Porcentaje de pedidos despachados en tiempo acordado', 95, 95, 0.15,
        unit: _percent),
    _Kpi('Nuevos comercios prospectados', 'Comercios contactados por primera vez, registrados', 11, 9, 0.15),
    _Kpi('Seguimientos a potenciales clientes', 'Contactos efectivos con oportunidad de venta', 18, 18, 0.10),
    _Kpi('Cotizaciones enviadas', 'Cotizaciones completas, precio autorizado', 8, 8, 0.10),
    _Kpi('Cierre de caja diaria de ventas de todo el equipo',
        'Caja diaria contra cobros y pedidos; cierre validado por Jime', 100, 100, 0.20, unit: _percent),
    _Kpi('Informe semanal de almacén y ventas', 'Con inventario, pedidos, despachos, B2B', 1, 1, 0.10),
  ]),
  '4': _Profile(shareRate: 0.20, minimumPercent: 80, monthCommission: '412.50', kpis: [
    _Kpi('Nuevos compradores contactados', 'Contactos prospectados, no duplicados', 27, 25, 0.30),
    _Kpi('Seguimientos comerciales', 'Clientes contactados después del primer interés', 14, 13, 0.20),
    _Kpi('Pedidos propios efectivamente pagados', 'Ventas personales cobradas, sin duplicación', 6, 4, 0.40,
        evidence: _Seed.paidOrder),
    _Kpi('Registro semanal de ventas', 'Pedidos, clientes y evidencias de cobro', 1, 1, 0.10,
        evidence: _Seed.registroInReview),
  ]),
  '5': _Profile(shareRate: 0.20, minimumPercent: 90, monthCommission: '595.00', kpis: [
    _Kpi('Nuevos comercios contactados', 'Contactos efectivos de clientes mayoristas', 11, 11, 0.25),
    _Kpi('Seguimientos comerciales', 'Seguimiento verificable de prospectos', 11, 11, 0.20),
    _Kpi('Cotizaciones enviadas', 'Con condiciones y precio autorizado', 5, 5, 0.20),
    _Kpi('Reuniones o negociaciones comerciales', 'Llamada o visita efectiva con decisión de compra', 2, 2, 0.15),
    _Kpi('Nuevas cuentas mayoristas con pago', 'Primer pedido pagado de un cliente nuevo', 1, 0, 0.15,
        evidence: _Seed.missing),
    _Kpi('Reporte de cartera semanal', 'Registro de prospectos y avance de negociación', 1, 1, 0.05),
  ]),
  '6': _Profile(shareRate: 0.10, minimumPercent: 90, kpis: [
    _Kpi('Fichas, fotos y precios web sin errores',
        'Auditoría semanal de productos prioritarios contra catálogo autorizado', 100, 100, 0.20, unit: _percent),
    _Kpi('Campañas y productos web actualizados a tiempo',
        'Cambios solicitados por Ailén aprobados y publicados en el plazo', 95, 95, 0.15, unit: _percent),
    _Kpi('Sitio disponible y compra navegable',
        'Monitoreo de disponibilidad web y prueba del recorrido de compra', 99, 99, 0.25, unit: _percent),
    _Kpi('Mejora web implementada e informe',
        'Una mejora útil validada por Dirección + resumen semanal', 1, 1, 0.10),
    _Kpi('Integración web ↔ sistema comercial sin errores',
        'Pruebas de pedidos, pagos, origen y stock visibles en panel de Jime', 100, 100, 0.30, unit: _percent),
  ]),
  '7': _Profile(shareRate: 0.10, minimumPercent: 90, kpis: [
    _Kpi('Ventas y pagos correctamente conciliados',
        'Pruebas y muestreo: web/pasarela contra pedidos y cobros', 100, 100, 0.20, unit: _percent),
    _Kpi('Inventario sincronizado con ventas',
        'Muestreo de registros físicos/pedidos, sin diferencias de stock', 99, 97, 0.20, unit: _percent),
    _Kpi('Comisiones calculadas automáticamente sin error',
        'Auditoría de comisiones individuales por producto y atribución', 100, 98, 0.15, unit: _percent),
    _Kpi('Mejora de sistema implementada e informe',
        'Una corrección o mejora funcional + resumen semanal', 1, 1, 0.10),
    _Kpi('KPI, comisiones y bonos automatizados sin errores',
        'Pruebas aprobadas por Jime: KPI, % por SKU, comisión mensual y bono semanal', 100, 90, 0.35,
        unit: _percent),
  ]),
};

/// Las siete semanas de la campaña: etiqueta, fechas, meta y premio base.
final _campaign = [
  ('1–6 dic', DateTime(2026, 12, 1), DateTime(2026, 12, 6), '40000', '1500'),
  ('7–13 dic', DateTime(2026, 12, 7), DateTime(2026, 12, 13), '60000', '2500'),
  ('14–20 dic', DateTime(2026, 12, 14), DateTime(2026, 12, 20), '85000', '3500'),
  ('21–27 dic', DateTime(2026, 12, 21), DateTime(2026, 12, 27), '100000', '4500'),
  ('28 dic–3 ene', DateTime(2026, 12, 28), DateTime(2027, 1, 3), '55000', '2500'),
  ('4–10 ene', DateTime(2027, 1, 4), DateTime(2027, 1, 10), '70000', '3500'),
  ('11–14 ene', DateTime(2027, 1, 11), DateTime(2027, 1, 14), '40000', '2000'),
];
