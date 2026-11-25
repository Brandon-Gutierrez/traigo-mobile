import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/demo/demo_backend.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/core/network/api_exception.dart';
import 'package:traigo/features/auth/domain/auth.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/kpi.dart';
import 'package:traigo/features/team/domain/my_week.dart';

Matcher conflict(String code) =>
    throwsA(isA<ConflictException>().having((e) => e.code, 'code', code));
final Matcher invalid = throwsA(isA<ValidationException>());
final Matcher notFound = throwsA(isA<NotFoundException>());

void main() {
  late DemoBackend backend;

  setUp(() => backend = DemoBackend(clock: () => DateTime(2026, 11, 24, 11, 40)));

  Member as(String code) {
    backend.login(code, '1234');
    return backend.current!;
  }

  WeekIndicator indicator(Member member, String name) => backend.team
      .myWeek(member)
      .indicators
      .singleWhere((i) => i.indicator.name == name);

  Evidence send(Member member, WeekIndicator target, NewEvidence evidence) =>
      backend.team.submitEvidence(member, target.indicator.id, evidence);

  const link = NewEvidence.link(clientUuid: 'k-1', url: 'drive.google.com/informe');

  group('mi semana', () {
    test('trae cómo se verifica, la unidad y la evidencia de cada indicador', () {
      final week = backend.team.myWeek(as('ALI-04'));

      expect(week.countTargetFactor, 0.9);
      expect(week.scorePercent, 83);
      expect(week.acceptsEvidence, isTrue);
      expect(week.deliverables, isEmpty);
      final registro = week.indicators.last;
      expect(registro.howVerified, 'Pedidos, clientes y evidencias de cobro');
      expect(registro.indicator.evidence, EvidenceStatus.inReview);
      expect(registro.evidence.single.kind, EvidenceKind.photo);
    });

    test('lo que falta va primero lo observado, luego lo vacío y lo en revisión', () {
      final ailen = backend.team.myWeek(as('AIL-02')).awaitingEvidence;
      expect(ailen.map((i) => i.indicator.evidence),
          [EvidenceStatus.observed, EvidenceStatus.inReview]);
      expect(ailen.first.evidence.first.reviewNote, isNotEmpty);

      final kim = backend.team.myWeek(as('KIM-05')).awaitingEvidence;
      expect(kim.single.indicator.evidence, EvidenceStatus.missing);
    });

    test('solo existe la primera semana y es del equipo', () {
      final alison = as('ALI-04');
      expect(() => backend.team.myWeek(alison, weekNumber: 2), notFound);
      expect(backend.team.myWeek(alison, weekNumber: 1).weekNumber, 1);
      backend.verifyTwoFactor(
          (backend.login('JIM-01', '1234') as NeedsSecondStep).challenge.id, '123456');
      expect(() => backend.team.myWeek(backend.current!), notFound);
    });
  });

  group('evidencia', () {
    test('un envío deja el indicador en revisión y se refleja en el resumen', () {
      final kim = as('KIM-05');
      final cuentas = indicator(kim, 'Nuevas cuentas mayoristas con pago');

      final saved = send(kim, cuentas, link);

      expect(saved.status, EvidenceStatus.inReview);
      expect(saved.url, 'https://drive.google.com/informe');
      final after = indicator(kim, 'Nuevas cuentas mayoristas con pago');
      expect(after.indicator.evidence, EvidenceStatus.inReview);
      expect(backend.home().kpi.indicators[4].evidence, EvidenceStatus.inReview);

      backend.verifyTwoFactor(
          (backend.login('JIM-01', '1234') as NeedsSecondStep).challenge.id, '123456');
      expect(backend.controlSummary().pending.evidence, 3);
    });

    test('la misma clave no se guarda dos veces', () {
      final kim = as('KIM-05');
      final cuentas = indicator(kim, 'Nuevas cuentas mayoristas con pago');

      final first = send(kim, cuentas, link);
      final again = send(kim, cuentas, link);

      expect(again.id, first.id);
      expect(indicator(kim, 'Nuevas cuentas mayoristas con pago').evidence, hasLength(1));
    });

    test('lo que Jime ya validó no admite más', () {
      final alison = as('ALI-04');
      final contactos = indicator(alison, 'Nuevos compradores contactados');

      expect(() => send(alison, contactos, link), conflict('evidence_validated'));
    });

    test('solo el indicador propio y con un enlace válido', () {
      final kim = as('KIM-05');
      final cuentas = indicator(kim, 'Nuevas cuentas mayoristas con pago');
      expect(
        () => send(kim, cuentas, const NewEvidence.link(clientUuid: 'k-2', url: 'no es')),
        invalid,
      );
      expect(() => send(as('ALI-04'), cuentas, link), notFound);
    });

    test('como pedido: solo quienes venden, con un pedido propio y vigente', () {
      final alison = as('ALI-04');
      final registro = indicator(alison, 'Registro semanal de ventas');

      final saved = send(
          alison, registro, const NewEvidence.order(clientUuid: 'o-1', orderId: '1046'));
      expect(saved.orderNumber, 'N-1046');
      expect(
        () => send(
            alison, registro, const NewEvidence.order(clientUuid: 'o-2', orderId: '1038')),
        invalid,
        reason: 'está cancelado',
      );
      expect(
        () => send(
            alison, registro, const NewEvidence.order(clientUuid: 'o-3', orderId: '1043')),
        notFound,
        reason: 'es de Kim',
      );

      final ailen = as('AIL-02');
      final lives = indicator(ailen, 'LIVES realizados');
      expect(
        () => send(
            ailen, lives, const NewEvidence.order(clientUuid: 'o-4', orderId: '1046')),
        invalid,
      );
    });
  });

  group('entregas de Sistemas', () {
    Deliverable submit(Member member, String id, {DateTime? on, String key = 'd-1'}) =>
        backend.team.submitDeliverable(
          member,
          id,
          deliveredOn: on ?? DateTime(2026, 11, 30),
          clientUuid: key,
          url: 'https://example.com/prueba',
        );

    test('de la primera semana, cada ingeniero ve sus cuatro', () {
      final one = backend.team.myWeek(as('SIS-06')).deliverables;
      expect(one, hasLength(4));
      expect(one.where((d) => d.isValidated), hasLength(2));
      expect(backend.team.deliverablesInReview, 1);
      expect(backend.team.myWeek(as('SIS-07')).openDeliverables, isEmpty);
    });

    test('enviar la deja en revisión con la fecha que se puso', () {
      final sistemas = as('SIS-06');

      final saved = submit(sistemas, 'd-3', on: DateTime(2026, 11, 29));

      expect(saved.status, DeliverableStatus.inReview);
      expect(saved.deliveredOn, DateTime(2026, 11, 29));
      expect(backend.team.deliverablesInReview, 2);
      expect(backend.home().kpi.deliverables!.approved, 2, reason: 'falta que Jime valide');
    });

    test('las validadas no se reenvían y las ajenas no existen', () {
      final sistemas = as('SIS-06');
      expect(() => submit(sistemas, 'd-1'), conflict('deliverable_validated'));
      expect(() => submit(sistemas, 'd-5'), notFound);
    });

    test('la fecha no puede ser futura y hace falta evidencia', () {
      final sistemas = as('SIS-06');
      expect(() => submit(sistemas, 'd-3', on: DateTime(2026, 12, 7)), invalid);
      expect(
        () => backend.team.submitDeliverable(
          sistemas,
          'd-3',
          deliveredOn: DateTime(2026, 11, 30),
          clientUuid: 'sin-nada',
        ),
        invalid,
      );
    });
  });

  test('«Equipo»: escalones con mi parte y las siete semanas', () {
    final team = backend.team.teamWeek(as('ALI-04'));

    expect(team.percent, 104);
    expect(team.tiers.map((t) => t.salesNeeded),
        [Money.parse('36000'), Money.parse('40000'), Money.parse('46000')]);
    expect(team.tiers.map((t) => t.myShare),
        [Money.parse('150'), Money.parse('300'), Money.parse('375')]);
    expect(team.myCompliance, Compliance.passes);
    expect(team.weeks, hasLength(7));
    expect(team.weeks.where((w) => w.isCurrent).single.number, 1);
    expect(team.weeks.last.week.label, '11–14 ene');
  });
}
