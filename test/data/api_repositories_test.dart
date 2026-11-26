import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/data/auth_api_repository.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/control/data/control_api_repository.dart';
import 'package:traigo/features/home/data/home_api_repository.dart';
import 'package:traigo/features/home/domain/home.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/kpi.dart';

import '../fixtures/api_samples.dart';
import '../support/fake_http_adapter.dart';

/// Comprueban que la app habla el contrato de docs/api-contract.md:
/// rutas, cuerpos y cómo interpreta cada respuesta o error.
void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness(token: null));

  AuthApiRepository auth([ApiHarness? harness]) {
    final target = harness ?? h;
    return AuthApiRepository(target.api, target.tokens);
  }

  group('ingreso', () {
    test('envía el código en mayúsculas, guarda el token y devuelve la sesión', () async {
      h.adapter.reply(200, loginResponse);

      final outcome = await auth().login(code: ' ali-04 ', pin: '1234', deviceName: 'Pixel');

      expect(h.adapter.last.method, 'POST');
      expect(h.adapter.last.uri.toString(), 'http://test.local/api/v1/auth/login');
      expect(h.adapter.last.data, {'code': 'ALI-04', 'pin': '1234', 'device_name': 'Pixel'});
      final session = (outcome as SignedIn).session;
      expect(session.member.name, 'Alison');
      expect(session.member.role, MemberRole.seller);
      expect(await h.tokens.read(), '12|k9sPq3');
    });

    test('Jime recibe un segundo paso y todavía no se guarda ningún token', () async {
      h.adapter.reply(200, secondStepResponse);

      final outcome = await auth().login(code: 'JIM-01', pin: '1234', deviceName: 'Pixel');

      final challenge = (outcome as NeedsSecondStep).challenge;
      expect(challenge.id, '9f3a1c');
      expect(challenge.codeLength, 6);
      expect(challenge.expiresAt.isAfter(challenge.resendAt), isTrue);
      expect(await h.tokens.read(), isNull);
    });

    test('un PIN incorrecto (401) no cuenta como sesión vencida', () async {
      h.adapter.reply(401, invalidCredentialsError);

      await expectLater(
        auth().login(code: 'ALI-04', pin: '0000', deviceName: 'Pixel'),
        throwsA(isA<UnauthorizedException>()
            .having((e) => e.message, 'message', 'Código o PIN incorrectos.')),
      );
      expect(h.unauthorizedCalls, 0);
    });

    test('demasiados intentos (429) dice cuánto esperar', () async {
      h.adapter.reply(429, {'message': 'Demasiados intentos.'}, headers: {
        'retry-after': ['60'],
      });

      await expectLater(
        auth().login(code: 'ALI-04', pin: '0000', deviceName: 'Pixel'),
        throwsA(isA<RateLimitedException>()
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 60)),
      );
    });
  });

  group('segundo paso', () {
    test('envía el código de verificación y guarda el token', () async {
      h.adapter.reply(200, twoFactorResponse);

      final session = await auth()
          .verifyTwoFactor(challengeId: '9f3a1c', code: '481902', deviceName: 'Pixel');

      expect(h.adapter.last.uri.path, '/api/v1/auth/two-factor');
      expect(h.adapter.last.data,
          {'challenge_id': '9f3a1c', 'code': '481902', 'device_name': 'Pixel'});
      expect(session.member.role, MemberRole.control);
      expect(await h.tokens.read(), '13|Zr81aa');
    });

    test('un código equivocado (422) llega con su motivo', () async {
      h.adapter.reply(422, invalidSecondStepError);

      await expectLater(
        auth().verifyTwoFactor(challengeId: '9f3a1c', code: '000000', deviceName: 'Pixel'),
        throwsA(isA<ValidationException>().having((e) => e.code, 'code', 'two_factor_invalid')),
      );
      expect(await h.tokens.read(), isNull);
    });

    test('reenviar devuelve el nuevo desafío', () async {
      h.adapter.reply(200, resendResponse);

      final challenge = await auth().resendTwoFactor('9f3a1c');

      expect(h.adapter.last.uri.path, '/api/v1/auth/two-factor/resend');
      expect(h.adapter.last.data, {'challenge_id': '9f3a1c'});
      expect(challenge.id, '71be02');
    });
  });

  group('sesión guardada', () {
    test('sin token no llama al servidor', () async {
      expect(await auth().restore(), isNull);
      expect(h.adapter.requests, isEmpty);
    });

    test('con token válido devuelve la sesión y lo envía en la cabecera', () async {
      final signedIn = ApiHarness();
      signedIn.adapter.reply(200, meResponse);

      final session = await auth(signedIn).restore();

      expect(session?.member.code, 'ALI-04');
      expect(signedIn.adapter.last.uri.path, '/api/v1/me');
      expect(signedIn.adapter.last.headers['Authorization'], 'Bearer tok');
    });

    test('con token revocado (401) lo borra', () async {
      final signedIn = ApiHarness();
      signedIn.adapter.reply(401, {'message': 'Unauthenticated.'});

      expect(await auth(signedIn).restore(), isNull);
      expect(await signedIn.tokens.read(), isNull);
    });

    test('sin internet NO borra el token', () async {
      final signedIn = ApiHarness();
      signedIn.adapter.failConnection();

      await expectLater(auth(signedIn).restore(), throwsA(isA<NetworkException>()));
      expect(await signedIn.tokens.read(), 'tok');
    });

    test('cerrar sesión borra el token aunque el servidor falle', () async {
      final signedIn = ApiHarness();
      signedIn.adapter.reply(500, {'message': 'Error.'});

      await auth(signedIn).logout();

      expect(signedIn.adapter.last.uri.path, '/api/v1/auth/logout');
      expect(await signedIn.tokens.read(), isNull);
    });
  });

  group('Inicio del equipo', () {
    Future<TeamHome> load(Object response) {
      h.adapter.reply(200, response);
      return HomeApiRepository(h.api).load();
    }

    test('lee el Inicio de quien vende', () async {
      final home = await load(sellerHomeResponse);

      expect(h.adapter.last.uri.path, '/api/v1/home');
      expect(home.percent, 104);
      expect(home.level, BonusLevel.complete);
      expect(home.shareAt(BonusLevel.complete), Money.parse('300'));
      expect(home.kpi.compliance, Compliance.passes);
      expect(home.kpi.indicators.last.actual, isNull);
      expect(home.kpi.indicators.last.evidence, EvidenceStatus.inReview);
      expect(home.kpi.deliverables, isNull);
      expect(home.monthCommission?.amount, Money.parse('412.50'));
      expect(home.monthCommission?.payNote, isNull);
      expect(home.todaySales.single.paymentMethod, PaymentMethod.qr);
      expect(home.cashToday, isNull);
    });

    test('la comisión sin % definido llega sin monto', () async {
      final home = await load({
        'data': {
          ...sellerHomeResponse['data']!,
          'month_commission': {'amount': null, 'pay_note': null},
        },
      });

      expect(home.monthCommission, isNotNull);
      expect(home.monthCommission!.amount, isNull);
    });

    test('lee la caja del día de almacén', () async {
      final home = await load(warehouseHomeResponse);

      expect(home.cashToday?.status, CashStatus.open);
      expect(home.cashToday?.collected, Money.parse('4968'));
      expect(home.monthCommission, isNull);
      expect(home.fundShareRate, 0.2);
    });

    test('lee las entregas de Sistemas; las listas ausentes quedan vacías', () async {
      final home = await load(systemsHomeResponse);

      expect(home.kpi.deliverables?.complete, isFalse);
      expect(home.kpi.closedReason, isNull);
      expect(home.todaySales, isEmpty);
    });

    test('un 401 con sesión avisa para volver al ingreso', () async {
      final signedIn = ApiHarness();
      signedIn.adapter.reply(401, {'message': 'Unauthenticated.'});

      await expectLater(
        HomeApiRepository(signedIn.api).load(),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(signedIn.unauthorizedCalls, 1);
    });
  });

  test('lee el resumen de control', () async {
    h.adapter.reply(200, controlSummaryResponse);

    final summary = await ControlApiRepository(h.api).summary();

    expect(h.adapter.last.uri.path, '/api/v1/control/summary');
    expect(summary.pending.total, 7);
    expect(summary.members.first.compliance, Compliance.fails);
    expect(summary.members.last.note, '2 de 4 entregas validadas');
    expect(summary.bonus.level, BonusLevel.complete);
    expect(summary.bonus.unpaid, Money.parse('450'));
  });
}
