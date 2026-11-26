import '../../features/auth/domain/auth.dart';
import '../../features/control/domain/control_summary.dart';
import '../../features/home/domain/home.dart';
import '../../features/team/domain/bonus.dart';
import '../money/money.dart';
import '../network/api_exception.dart';
import 'demo_audit.dart';
import 'demo_control.dart';
import 'demo_sales.dart';
import 'demo_team.dart';
import 'demo_warehouse.dart';

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

  /// El historial de cambios.
  late final DemoAudit audit = DemoAudit(now: _demoNow);

  /// Caja, despachos, stock y conteos.
  late final DemoWarehouse warehouse =
      DemoWarehouse(now: _demoNow, sales: sales, audit: audit);

  /// El panel de Jime y las autorizaciones de Dirección.
  late final DemoControl control = DemoControl(
    now: _demoNow,
    sales: sales,
    team: team,
    warehouse: warehouse,
    audit: audit,
  );

  /// La hora de [time], en el día de la demo.
  static DateTime atDemoDay(DateTime time) =>
      DateTime(today.year, today.month, today.day, time.hour, time.minute, time.second);

  DateTime _demoNow() => atDemoDay(_clock());

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
    // Jime puede haber cambiado el PIN de alguien del equipo.
    if (member == null || enteredPin != (control.pins[member.id] ?? pin)) {
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
    return TeamHome(
      week: week,
      collected: collected,
      fundShareRate: team.shareRate(member.id),
      kpi: team.kpiOf(member.id),
      monthCommission: member.role.canSell ? _monthCommission(member.id) : null,
      todaySales: sales.todaySales(member.id, today),
      cashToday: member.role == MemberRole.warehouse ? warehouse.todaySummary() : null,
    );
  }

  /// Lo cobrado este mes; sin monto mientras falte el % de alguna venta.
  MonthCommission _monthCommission(String sellerId) {
    final month = sales.commissionsOf(sellerId, today);
    return MonthCommission(
      amount: month.ratesPending ? null : month.rated + month.adjustments,
    );
  }

  // ---------------------------------------------------------------- Control

  ControlSummary controlSummary() {
    requireControlSide();
    return control.summary();
  }

  /// Jime o Dirección (lo que ambos pueden leer).
  Member requireControlSide() {
    final member = requireMember();
    if (!member.role.isControlSide) {
      throw const NotFoundException('Solo Jime y Dirección ven el panel de control.');
    }
    return member;
  }

  /// Solo Jime valida y propone.
  Member requireControl() => _requireRole(MemberRole.control, 'Solo Jime hace esto.');

  /// Solo Dirección autoriza.
  Member requireManagement() =>
      _requireRole(MemberRole.management, 'Solo Dirección hace esto.');

  Member _requireRole(MemberRole role, String message) {
    final member = requireMember();
    if (member.role != role) throw NotFoundException(message);
    return member;
  }

  Member requireMember() {
    final member = current;
    if (member == null) {
      throw const UnauthorizedException('Tu sesión terminó. Ingresa otra vez.');
    }
    return member;
  }
}
