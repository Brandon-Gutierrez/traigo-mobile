import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traigo/core/money/money.dart';
import 'package:traigo/features/orders/domain/orders.dart';
import 'package:traigo/features/team/data/team_api_repository.dart';
import 'package:traigo/features/team/domain/bonus.dart';
import 'package:traigo/features/team/domain/kpi.dart';
import 'package:traigo/features/team/domain/my_week.dart';
import 'package:traigo/features/warehouse/data/warehouse_api_repository.dart';
import 'package:traigo/features/warehouse/domain/warehouse.dart';

import '../fixtures/team_samples.dart';
import '../support/fake_http_adapter.dart';

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  String path() => h.adapter.last.uri.path.replaceFirst('/api/v1', '');

  group('equipo y mi semana', () {
    test('lee los escalones y las semanas de la campaña', () async {
      h.adapter.reply(200, teamWeekResponse);

      final team = await TeamApiRepository(h.api).teamWeek();

      expect(path(), '/team/week');
      expect(team.percent, 78);
      expect(team.tiers.map((t) => t.tier),
          [BonusLevel.partial, BonusLevel.complete, BonusLevel.superior]);
      expect(team.tiers.last.myShare, Money.parse('375'));
      expect(team.weeks.first.isCurrent, isTrue);
      expect(team.weeks.last.week.target, Money.parse('60000'));
    });

    test('lee mi semana con su evidencia', () async {
      h.adapter.reply(200, myWeekResponse);

      final week = await TeamApiRepository(h.api).myWeek(weekNumber: 1);

      expect(path(), '/me/week');
      expect(h.adapter.last.uri.queryParameters, {'week': '1'});
      expect(week.countTargetFactor, 0.9);
      expect(week.scorePercent, isNull);
      expect(week.acceptsEvidence, isTrue);
      expect(week.compliance, Compliance.pending);
      final indicator = week.indicators.single;
      expect(indicator.unit, KpiUnit.count);
      expect(indicator.indicator.evidence, EvidenceStatus.inReview);
      expect(indicator.evidence.single.kind, EvidenceKind.photo);
    });

    test('sube un enlace como evidencia, con su clave contra duplicados', () async {
      h.adapter.reply(201, evidenceResponse);

      await TeamApiRepository(h.api).submitEvidence(
        'r-44',
        const NewEvidence.link(clientUuid: 'uuid-1', url: 'https://tiktok.com/x'),
      );

      expect(path(), '/me/kpi-results/r-44/evidence');
      expect(h.adapter.last.headers['Idempotency-Key'], 'uuid-1');
      final form = h.adapter.last.data as FormData;
      expect(Map.fromEntries(form.fields), {'kind': 'link', 'url': 'https://tiktok.com/x'});
    });

    test('sube una foto como archivo', () async {
      h.adapter.reply(201, evidenceResponse);
      final dir = await Directory.systemTemp.createTemp('traigo');
      addTearDown(() => dir.delete(recursive: true));
      final photo = await File('${dir.path}/foto.jpg').writeAsBytes([1, 2, 3]);

      await TeamApiRepository(h.api).submitEvidence(
        'r-44',
        NewEvidence.photo(
          clientUuid: 'uuid-2',
          file: UploadFile(path: photo.path, filename: 'foto.jpg'),
        ),
      );

      final form = h.adapter.last.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'foto.jpg');
    });

    test('envía una entrega de Sistemas con su fecha real', () async {
      h.adapter.reply(200, deliverableResponse);

      final deliverable = await TeamApiRepository(h.api).submitDeliverable(
        'd-1',
        deliveredOn: DateTime(2026, 11, 30),
        url: 'https://traigo.bo',
        clientUuid: 'uuid-3',
      );

      expect(path(), '/me/deliverables/d-1/submission');
      final form = h.adapter.last.data as FormData;
      expect(Map.fromEntries(form.fields),
          {'delivered_on': '2026-11-30', 'url': 'https://traigo.bo'});
      expect(deliverable.status, DeliverableStatus.onTime);
    });
  });

  group('almacén', () {
    test('lee la caja del día con diferencias y pendientes', () async {
      h.adapter.reply(200, cashDayResponse);

      final day = await WarehouseApiRepository(h.api).cashToday();

      expect(path(), '/cash/today');
      expect(day.status, CashStatus.sent);
      expect(day.canSend, isFalse);
      expect(day.lines.last.difference, Money.parse('-50'));
      expect(day.pending.single.sellerName, 'Alison');
      expect(day.pendingDays.single.status, CashStatus.observed);
    });

    test('pide la caja de un día anterior', () async {
      h.adapter.reply(200, cashDayResponse);

      await WarehouseApiRepository(h.api).cashDay(DateTime(2026, 12, 1));

      expect(path(), '/cash/days/2026-12-01');
    });

    test('envía el cierre con lo contado por forma de pago', () async {
      h.adapter.reply(201, cashDayResponse);

      await WarehouseApiRepository(h.api).sendClosing(NewCashClosing(
        clientUuid: 'uuid-4',
        businessDate: DateTime(2026, 12, 1),
        counted: {
          PaymentMethod.qr: Money.parse('2140'),
          PaymentMethod.cash: Money.parse('810'),
        },
        note: 'Faltan Bs 50 de cambio, se revisa mañana.',
      ));

      expect(path(), '/cash/closings');
      expect(h.adapter.last.data, cashClosingRequest);
      expect(h.adapter.last.headers['Idempotency-Key'], 'uuid-4');
    });

    test('registra un conteo y lee la diferencia', () async {
      h.adapter
        ..reply(201, inventoryCountResponse)
        ..reply(200, inventoryCountsResponse);
      final repo = WarehouseApiRepository(h.api);

      final count = await repo.submitCount(
        clientUuid: 'uuid-5',
        countedOn: DateTime(2026, 12, 4),
        counted: {'p-8109': 36},
      );
      expect(h.adapter.last.data, inventoryCountRequest);
      expect(count.items.single.difference, -2);
      expect(await repo.counts(), hasLength(1));
    });

    test('lee los despachos y marca listo y entregado', () async {
      h.adapter
        ..reply(200, dispatchesResponse)
        ..reply(204, {})
        ..reply(204, {});
      final repo = WarehouseApiRepository(h.api);

      final queue = await repo.dispatchQueue();
      expect(path(), '/warehouse/dispatches');
      expect(queue.single.status, OrderStatus.paid);
      expect(queue.single.deliveryType, DeliveryType.delivery);
      expect(queue.single.lines.single.quantity, 24);

      await repo.markReady('o-1043');
      expect(path(), '/warehouse/orders/o-1043/ready');
      await repo.markDelivered('o-1043');
      expect(path(), '/warehouse/orders/o-1043/delivered');
    });

    test('un ajuste que falta viaja en negativo', () async {
      h.adapter.reply(201, stockLevelResponse);

      final level = await WarehouseApiRepository(h.api).registerStock(
        clientUuid: 'uuid-6',
        productId: 'p-8109',
        type: StockEntryType.adjustmentOut,
        quantity: 2,
        note: 'Conteo del viernes',
        inventoryCountId: 'ic-1',
      );

      expect(path(), '/inventory/movements');
      expect(h.adapter.last.data, stockEntryRequest);
      expect(level.available, 36);
    });
  });
}
