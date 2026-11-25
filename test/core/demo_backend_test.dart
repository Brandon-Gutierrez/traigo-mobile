import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/home/domain/home.dart';
import 'package:traigo/features/team/domain/bonus.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<ValidationException>().having((e) => e.code, 'code', code));

void main() {
  late DateTime now;
  late DemoBackend backend;

  setUp(() {
    now = DateTime(2026, 12, 6, 18);
    backend = DemoBackend(clock: () => now);
  });

  TwoFactorChallenge challengeFor(String code) =>
      (backend.login(code, '1234') as NeedsSecondStep).challenge;

  TeamHome homeOf(String code) {
    backend.login(code, '1234');
    return backend.home();
  }

  group('ingreso', () {
    test('el PIN o el código equivocados no entran', () {
      expect(() => backend.login('ALI-04', '0000'), throwsA(isA<UnauthorizedException>()));
      expect(() => backend.login('NADIE-1', '1234'), throwsA(isA<UnauthorizedException>()));
      expect(backend.current, isNull);
    });

    test('el equipo entra directo; el código no distingue mayúsculas', () {
      final outcome = backend.login(' ali-04 ', '1234');
      expect((outcome as SignedIn).session.member.name, 'Alison');
    });

    test('Jime y Dirección necesitan el segundo paso', () {
      for (final code in ['JIM-01', 'DIR-08']) {
        expect(backend.login(code, '1234'), isA<NeedsSecondStep>(), reason: code);
        expect(backend.current, isNull);
      }
    });

    test('un código de verificación equivocado no entra y permite reintentar', () {
      final challenge = challengeFor('JIM-01');
      expect(
        () => backend.verifyTwoFactor(challenge.id, '000000'),
        throwsCode('two_factor_invalid'),
      );
      final session = backend.verifyTwoFactor(challenge.id, '123456');
      expect(session.member.role, MemberRole.control);
    });

    test('el código de verificación vence', () {
      final challenge = challengeFor('JIM-01');
      now = now.add(const Duration(minutes: 5, seconds: 1));
      expect(
        () => backend.verifyTwoFactor(challenge.id, '123456'),
        throwsCode('two_factor_expired'),
      );
    });

    test('reenviar exige esperar y anula el código anterior', () {
      final first = challengeFor('DIR-08');
      expect(() => backend.resendTwoFactor(first.id), throwsA(isA<RateLimitedException>()));

      now = now.add(const Duration(seconds: 45));
      final second = backend.resendTwoFactor(first.id);
      expect(second.id, isNot(first.id));
      expect(
        () => backend.verifyTwoFactor(first.id, '123456'),
        throwsCode('two_factor_expired'),
      );
      expect(backend.verifyTwoFactor(second.id, '123456').member.name, 'Dirección');
    });
  });

  group('primera semana según el Excel', () {
    test('cada integrante tiene su puntaje, su mínimo y su resultado', () {
      const expected = {
        'AIL-02': (93, 90, Compliance.passes, 0.20),
        'ISA-03': (97, 90, Compliance.passes, 0.20),
        'ALI-04': (83, 80, Compliance.passes, 0.20),
        'KIM-05': (85, 90, Compliance.fails, 0.20),
        'SIS-06': (100, 90, Compliance.pending, 0.10),
        'SIS-07': (95, 90, Compliance.passes, 0.10),
      };
      for (final MapEntry(key: code, value: (score, minimum, compliance, share))
          in expected.entries) {
        final home = homeOf(code);
        expect(home.kpi.scorePercent, score, reason: code);
        expect(home.kpi.minimumPercent, minimum, reason: code);
        expect(home.kpi.compliance, compliance, reason: code);
        expect(home.fundShareRate, share, reason: code);
        expect(
          home.kpi.indicators.fold<double>(0, (sum, i) => sum + i.weight),
          closeTo(1, 1e-9),
          reason: 'los pesos de $code suman 100 %',
        );
      }
    });

    test('las partes del fondo suman 100 %', () {
      final rates = [
        for (final m in DemoBackend.members.where((m) => !m.role.isControlSide))
          homeOf(m.code).fundShareRate,
      ];
      expect(rates.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
    });

    test('cada puesto recibe solo lo suyo', () {
      final alison = homeOf('ALI-04');
      expect(alison.monthCommission?.amount, Money.parse('412.50'));
      expect(alison.todaySales, hasLength(2));
      expect(alison.cashToday, isNull);

      final isai = homeOf('ISA-03');
      expect(isai.cashToday?.collected, Money.parse('4968'));
      expect(isai.monthCommission, isNull);
      expect(isai.todaySales, isEmpty);

      expect(homeOf('SIS-06').kpi.deliverables?.approved, 2);
      expect(homeOf('AIL-02').kpi.deliverables, isNull);
    });

    test('el resumen de control cuadra con lo que ve cada integrante', () {
      final evidenceInReview = [
        for (final m in DemoBackend.members.where((m) => !m.role.isControlSide))
          ...homeOf(m.code).kpi.indicators.where((i) => i.evidence.apiValue == 'in_review'),
      ];

      backend.verifyTwoFactor(challengeFor('JIM-01').id, '123456');
      final summary = backend.controlSummary();

      expect(summary.percent, 104);
      expect(summary.members, hasLength(6));
      expect(summary.pending.evidence, evidenceInReview.length);
      expect(summary.pending.total, 7);
      expect(summary.bonus.level, BonusLevel.complete);
      expect(summary.bonus.payable, Money.parse('1050'));
      expect(summary.bonus.unpaidFailing, Money.parse('300'));
      expect(summary.bonus.unpaidPending, Money.parse('150'));
      expect(
        summary.members.singleWhere((m) => m.name == 'Sistemas 1').note,
        '2 de 4 entregas validadas',
      );
    });

    test('cada lado solo ve lo suyo y sin sesión no hay datos', () {
      expect(backend.home, throwsA(isA<UnauthorizedException>()));
      backend.login('ALI-04', '1234');
      expect(backend.controlSummary, throwsA(isA<NotFoundException>()));
      backend.verifyTwoFactor(challengeFor('JIM-01').id, '123456');
      expect(backend.home, throwsA(isA<NotFoundException>()));
    });
  });
}
