import '../../features/auth/domain/auth.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/home/domain/home.dart';
import '../../features/team/domain/bonus.dart';
import '../../features/team/domain/kpi.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import 'demo_sales.dart';
import 'demo_team.dart';

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

  /// Catálogo y ventas.
  late final DemoSales sales = DemoSales(now: _demoNow);

  /// KPI, evidencia y entregas.
  late final DemoTeam team = DemoTeam(now: _demoNow, sales: sales);

  /// La hora actual, en el día de la demo.
  DateTime _demoNow() {
    final time = _clock();
    return DateTime(today.year, today.month, today.day, time.hour, time.minute, time.second);
  }

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
    final commission = team.monthCommission(member.id);
    return TeamHome(
      week: week,
      collected: collected,
      fundShareRate: team.shareRate(member.id),
      kpi: team.kpiOf(member.id),
      monthCommission: commission == null ? null : MonthCommission(amount: commission),
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
      final kpi = team.kpiOf(m.id);
      final shareRate = team.shareRate(m.id);
      evidenceInReview +=
          kpi.indicators.where((i) => i.evidence == EvidenceStatus.inReview).length;
      final deliverables = kpi.deliverables;
      results.add(MemberResult(
        id: m.id,
        name: m.name,
        scorePercent: kpi.scorePercent,
        minimumPercent: kpi.minimumPercent,
        compliance: kpi.compliance,
        fundShareRate: shareRate,
        note: deliverables != null && !deliverables.complete
            ? '${deliverables.approved} de ${deliverables.total} entregas validadas'
            : null,
      ));
      shares.add(BonusShare(name: m.name, rate: shareRate, compliance: kpi.compliance));
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
        deliverables: team.deliverablesInReview,
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
}
