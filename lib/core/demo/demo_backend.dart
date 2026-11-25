import '../../features/auth/domain/auth.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/home/domain/home.dart';
import '../../features/team/domain/bonus.dart';
import '../../features/team/domain/kpi.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import 'demo_sales.dart';

/// «Servidor» de prueba en memoria. Aplica las mismas reglas que debe aplicar
/// el backend real (ver docs/api-contract.md), así la app se puede desarrollar
/// y mostrar completa sin Laravel.
///
/// Foto de la campaña: **domingo 6 de diciembre**, cierre de la primera semana.
/// Metas, pesos, mínimos y reparto salen del Excel de Jime; las cifras
/// cobradas, los valores reales, las ventas y la caja son de ejemplo.
///
/// - Todos entran con PIN `1234` (códigos en [members]).
/// - Jime y Dirección además escriben el código `123456`.
class DemoBackend {
  DemoBackend({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const pin = '1234';
  static const secondStepCode = '123456';

  static const members = [
    Member(id: '1', code: 'JIM-01', name: 'Jime', role: MemberRole.control, title: 'Control y validación'),
    Member(id: '2', code: 'AIL-02', name: 'Ailén', role: MemberRole.content, title: 'Contenido y lives'),
    Member(id: '3', code: 'ISA-03', name: 'Isaí', role: MemberRole.warehouse, title: 'Almacén y caja'),
    Member(id: '4', code: 'ALI-04', name: 'Alison', role: MemberRole.seller, title: 'Ventas por comisión'),
    Member(id: '5', code: 'KIM-05', name: 'Kim', role: MemberRole.wholesale, title: 'Ventas mayoristas'),
    Member(id: '6', code: 'SIS-06', name: 'Sistemas 1', role: MemberRole.systems, title: 'Sistemas'),
    Member(id: '7', code: 'SIS-07', name: 'Sistemas 2', role: MemberRole.systems, title: 'Sistemas'),
    Member(id: '8', code: 'DIR-08', name: 'Dirección', role: MemberRole.management, title: 'Dirección'),
  ];

  static final week = BonusWeek(
    label: '1–6 dic',
    startsOn: DateTime(2026, 12, 1),
    endsOn: DateTime(2026, 12, 6),
    target: Money.parse('40000'),
    basePrize: Money.parse('1500'),
  );

  static final collected = Money.parse('41600');
  static final asOf = DateTime(2026, 12, 6, 18);

  /// El «hoy» de la demo.
  static final today = DateTime(2026, 12, 6);

  /// Catálogo y ventas. La hora es la actual, en el día de la demo.
  late final DemoSales sales = DemoSales(now: () {
    final time = _clock();
    return DateTime(today.year, today.month, today.day, time.hour, time.minute, time.second);
  });

  static const _challengeLife = Duration(minutes: 5);
  static const _resendWait = Duration(seconds: 45);

  final DateTime Function() _clock;
  final Map<String, ({Member member, TwoFactorChallenge challenge})> _challenges = {};
  int _nextChallenge = 1;

  /// Quién tiene la sesión (el equivalente al token en el servidor).
  Member? current;

  // ---------------------------------------------------------------- Sesión

  LoginOutcome login(String code, String enteredPin) {
    final member = _byCode(code);
    if (member == null || enteredPin != pin) {
      throw const UnauthorizedException('Código o PIN incorrectos.');
    }
    if (member.role.isControlSide) {
      return NeedsSecondStep(_newChallenge(member));
    }
    current = member;
    return SignedIn(Session(member: member));
  }

  Session verifyTwoFactor(String challengeId, String code) {
    final entry = _challenges[challengeId];
    if (entry == null || _clock().isAfter(entry.challenge.expiresAt)) {
      throw const ValidationException(
        message: 'El código venció. Pide uno nuevo.',
        code: 'two_factor_expired',
      );
    }
    if (code != secondStepCode) {
      throw const ValidationException(
        message: 'El código no es correcto.',
        code: 'two_factor_invalid',
      );
    }
    _challenges.remove(challengeId);
    current = entry.member;
    return Session(member: entry.member);
  }

  TwoFactorChallenge resendTwoFactor(String challengeId) {
    final entry = _challenges[challengeId];
    if (entry == null) {
      throw const ValidationException(
        message: 'Vuelve a ingresar tu código y tu PIN.',
        code: 'two_factor_expired',
      );
    }
    final wait = entry.challenge.resendAt.difference(_clock());
    if (wait > Duration.zero) {
      throw RateLimitedException(
        'Espera un momento antes de pedir otro código.',
        retryAfterSeconds: wait.inSeconds + 1,
      );
    }
    _challenges.remove(challengeId);
    return _newChallenge(entry.member);
  }

  TwoFactorChallenge _newChallenge(Member member) {
    final now = _clock();
    final challenge = TwoFactorChallenge(
      id: 'demo-${_nextChallenge++}',
      expiresAt: now.add(_challengeLife),
      resendAt: now.add(_resendWait),
    );
    _challenges[challenge.id] = (member: member, challenge: challenge);
    return challenge;
  }

  Member? memberById(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Member? _byCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final m in members) {
      if (m.code == normalized) return m;
    }
    return null;
  }

  // ---------------------------------------------------------------- Inicio

  TeamHome home() {
    final member = requireMember();
    if (member.role.isControlSide) {
      throw const NotFoundException('El panel de control no tiene Inicio de equipo.');
    }
    final profile = _profiles[member.id]!;
    return TeamHome(
      week: week,
      collected: collected,
      fundShareRate: profile.shareRate,
      kpi: _kpiOf(profile),
      monthCommission: profile.monthCommission == null
          ? null
          : MonthCommission(amount: Money.parse(profile.monthCommission!)),
      todaySales: sales.todaySales(member.id, today),
      cashToday: member.role == MemberRole.warehouse
          ? CashToday(
              collected: Money.parse('4968'),
              paidOrders: 7,
              pendingOrders: 1,
              status: CashStatus.open,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------- Control

  ControlSummary controlSummary() {
    final member = requireMember();
    if (!member.role.isControlSide) {
      throw const NotFoundException('Solo Jime y Dirección ven el resumen de control.');
    }
    final results = <MemberResult>[];
    final shares = <BonusShare>[];
    var evidenceInReview = 0;
    for (final m in members.where((m) => !m.role.isControlSide)) {
      final profile = _profiles[m.id]!;
      final kpi = _kpiOf(profile);
      evidenceInReview +=
          kpi.indicators.where((i) => i.evidence == EvidenceStatus.inReview).length;
      final deliverables = kpi.deliverables;
      results.add(MemberResult(
        id: m.id,
        name: m.name,
        scorePercent: kpi.scorePercent,
        minimumPercent: kpi.minimumPercent,
        compliance: kpi.compliance,
        fundShareRate: profile.shareRate,
        note: deliverables != null && !deliverables.complete
            ? '${deliverables.approved} de ${deliverables.total} entregas validadas'
            : null,
      ));
      shares.add(BonusShare(name: m.name, rate: profile.shareRate, compliance: kpi.compliance));
    }
    final distribution = BonusRules.distribute(collected: collected, week: week, shares: shares);
    return ControlSummary(
      asOf: asOf,
      week: week,
      collected: collected,
      pending: PendingReview(
        payments: 3,
        evidence: evidenceInReview,
        cashClosings: 1,
        deliverables: 1,
      ),
      members: results,
      bonus: BonusResult(
        level: distribution.level,
        prize: distribution.prize,
        payable: distribution.payable,
        unpaidFailing: distribution.unpaidFailing,
        unpaidPending: distribution.unpaidPending,
      ),
    );
  }

  Member requireMember() {
    final member = current;
    if (member == null) {
      throw const UnauthorizedException('Tu sesión terminó. Ingresa otra vez.');
    }
    return member;
  }

  MyKpi _kpiOf(_Profile profile) {
    final indicators = [
      for (final (index, k) in profile.kpis.indexed)
        KpiIndicator(
          id: '${profile.memberId}-${index + 1}',
          name: k.name,
          target: k.target,
          actual: k.actual,
          weight: k.weight,
          evidence: k.evidence,
        ),
    ];
    final deliverables = profile.deliverables;
    return MyKpi(
      scorePercent: KpiRules.scorePercent(indicators),
      minimumPercent: profile.minimumPercent,
      compliance: KpiRules.compliance(
        indicators,
        minimumPercent: profile.minimumPercent,
        deliverablesApproved: deliverables?.complete ?? true,
      ),
      indicators: indicators,
      deliverables: deliverables,
    );
  }

}

// ──────────────────────────────────────────── datos de la primera semana

class _Kpi {
  const _Kpi(this.name, this.target, this.actual, this.weight, [this.evidence = EvidenceStatus.validated]);

  final String name;
  final double target;
  final double actual;
  final double weight;
  final EvidenceStatus evidence;
}

class _Profile {
  const _Profile({
    required this.memberId,
    required this.shareRate,
    required this.minimumPercent,
    required this.kpis,
    this.monthCommission,
    this.deliverables,
  });

  final String memberId;
  final double shareRate;
  final int minimumPercent;
  final List<_Kpi> kpis;
  final String? monthCommission;
  final DeliverableProgress? deliverables;
}

/// Indicadores, pesos y metas de la semana 1 (ya ajustadas al 90 %).
const _profiles = <String, _Profile>{
  '2': _Profile(memberId: '2', shareRate: 0.20, minimumPercent: 90, kpis: [
    _Kpi('Videos cortos publicados', 9, 9, 0.25),
    _Kpi('Historias y estados publicados', 17, 17, 0.10),
    _Kpi('Artes o fichas comerciales terminados', 6, 5, 0.15),
    _Kpi('LIVES realizados', 3, 3, 0.20, EvidenceStatus.inReview),
    _Kpi('Consultas calificadas generadas', 15, 12, 0.20),
    _Kpi('Informe semanal entregado', 1, 1, 0.10),
  ]),
  '3': _Profile(memberId: '3', shareRate: 0.20, minimumPercent: 90, kpis: [
    _Kpi('Exactitud del inventario', 98, 98, 0.20),
    _Kpi('Despachos dentro de plazo', 95, 95, 0.15),
    _Kpi('Nuevos comercios prospectados', 11, 9, 0.15),
    _Kpi('Seguimientos a potenciales clientes', 18, 18, 0.10),
    _Kpi('Cotizaciones enviadas', 8, 8, 0.10),
    _Kpi('Cierre de caja diaria de ventas de todo el equipo', 100, 100, 0.20),
    _Kpi('Informe semanal de almacén y ventas', 1, 1, 0.10),
  ]),
  '4': _Profile(memberId: '4', shareRate: 0.20, minimumPercent: 80, monthCommission: '412.50', kpis: [
    _Kpi('Nuevos compradores contactados', 27, 25, 0.30),
    _Kpi('Seguimientos comerciales', 14, 13, 0.20),
    _Kpi('Pedidos propios efectivamente pagados', 6, 4, 0.40),
    _Kpi('Registro semanal de ventas', 1, 1, 0.10, EvidenceStatus.inReview),
  ]),
  '5': _Profile(memberId: '5', shareRate: 0.20, minimumPercent: 90, monthCommission: '595.00', kpis: [
    _Kpi('Nuevos comercios contactados', 11, 11, 0.25),
    _Kpi('Seguimientos comerciales', 11, 11, 0.20),
    _Kpi('Cotizaciones enviadas', 5, 5, 0.20),
    _Kpi('Reuniones o negociaciones comerciales', 2, 2, 0.15),
    _Kpi('Nuevas cuentas mayoristas con pago', 1, 0, 0.15, EvidenceStatus.missing),
    _Kpi('Reporte de cartera semanal', 1, 1, 0.05),
  ]),
  '6': _Profile(
    memberId: '6',
    shareRate: 0.10,
    minimumPercent: 90,
    deliverables: DeliverableProgress(approved: 2, total: 4),
    kpis: [
      _Kpi('Fichas, fotos y precios web sin errores', 100, 100, 0.20),
      _Kpi('Campañas y productos web actualizados a tiempo', 95, 95, 0.15),
      _Kpi('Sitio disponible y compra navegable', 99, 99, 0.25),
      _Kpi('Mejora web implementada e informe', 1, 1, 0.10),
      _Kpi('Integración web ↔ sistema comercial sin errores', 100, 100, 0.30),
    ],
  ),
  '7': _Profile(
    memberId: '7',
    shareRate: 0.10,
    minimumPercent: 90,
    deliverables: DeliverableProgress(approved: 4, total: 4),
    kpis: [
      _Kpi('Ventas y pagos correctamente conciliados', 100, 100, 0.20),
      _Kpi('Inventario sincronizado con ventas', 99, 97, 0.20),
      _Kpi('Comisiones calculadas automáticamente sin error', 100, 98, 0.15),
      _Kpi('Mejora de sistema implementada e informe', 1, 1, 0.10),
      _Kpi('KPI, comisiones y bonos automatizados', 100, 90, 0.35),
    ],
  ),
};
