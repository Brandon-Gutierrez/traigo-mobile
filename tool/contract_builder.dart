/// Arma docs/api-contract.md a partir de tool/api-contract.template.md,
/// reemplazando cada `{{nombre}}` por el ejemplo de `test/fixtures/`. Así los
/// ejemplos del documento son exactamente los que prueban la app.
library;

import 'dart:convert';

import '../test/fixtures/api_samples.dart' as app;
import '../test/fixtures/panel_samples.dart' as panel;
import '../test/fixtures/sales_samples.dart' as sales;
import '../test/fixtures/team_samples.dart' as team;

const Map<String, Object> contractSamples = {
  // Ingreso, Inicio y resumen
  'loginResponse': app.loginResponse,
  'secondStepResponse': app.secondStepResponse,
  'resendResponse': app.resendResponse,
  'twoFactorResponse': app.twoFactorResponse,
  'meResponse': app.meResponse,
  'invalidSecondStepError': app.invalidSecondStepError,
  'sellerHomeResponse': app.sellerHomeResponse,
  'warehouseHomeResponse': app.warehouseHomeResponse,
  'systemsHomeResponse': app.systemsHomeResponse,
  'controlSummaryResponse': app.controlSummaryResponse,
  // Equipo y mi semana
  'teamWeekResponse': team.teamWeekResponse,
  'myWeekResponse': team.myWeekResponse,
  'evidenceResponse': team.evidenceResponse,
  'deliverableResponse': team.deliverableResponse,
  // Catálogo y ventas
  'catalogResponse': sales.catalogResponse,
  'categoriesResponse': sales.categoriesResponse,
  'catalogDetailResponse': sales.catalogDetailResponse,
  'ordersResponse': sales.ordersResponse,
  'newSaleRequest': sales.newSaleRequest,
  'orderDetailResponse': sales.orderDetailResponse,
  'priceChangedError': sales.priceChangedError,
  'insufficientStockError': sales.insufficientStockError,
  // Almacén
  'cashDayResponse': team.cashDayResponse,
  'cashClosingRequest': team.cashClosingRequest,
  'dispatchesResponse': team.dispatchesResponse,
  'stockEntryRequest': team.stockEntryRequest,
  'stockLevelResponse': team.stockLevelResponse,
  'inventoryCountRequest': team.inventoryCountRequest,
  'inventoryCountResponse': team.inventoryCountResponse,
  // Panel de Jime
  'pendingResponse': panel.pendingResponse,
  'paymentReviewResponse': panel.paymentReviewResponse,
  'confirmPaymentRequest': panel.confirmPaymentRequest,
  'evidenceReviewResponse': panel.evidenceReviewResponse,
  'returnOrderRequest': team.returnOrderRequest,
  'duplicateOrderRequest': team.duplicateOrderRequest,
  'complianceResponse': panel.complianceResponse,
  'weeklyClosingResponse': panel.weeklyClosingResponse,
  'sendClosingRequest': panel.sendClosingRequest,
  'bonusResponse': panel.bonusResponse,
  'commissionsResponse': panel.commissionsResponse,
  'priceSheetResponse': panel.priceSheetResponse,
  'priceChangeRequest': panel.priceChangeRequest,
  'auditResponse': panel.auditResponse,
  'systemStatusResponse': panel.systemStatusResponse,
  // Dirección
  'authorizationsResponse': panel.authorizationsResponse,
  'authorizationDetailResponse': panel.authorizationDetailResponse,
};

final _placeholder = RegExp(r'^\{\{(\w+)\}\}$', multiLine: true);

String buildContract(String template) {
  final used = <String>{};
  final text = template.replaceAll('\r\n', '\n').replaceAllMapped(_placeholder, (match) {
    final name = match.group(1)!;
    final sample = contractSamples[name];
    if (sample == null) throw StateError('No existe el ejemplo «$name».');
    used.add(name);
    return '```json\n${const JsonEncoder.withIndent('  ').convert(sample)}\n```';
  });

  final unused = contractSamples.keys.toSet().difference(used);
  if (unused.isNotEmpty) {
    throw StateError('Ejemplos que el documento no muestra: ${unused.join(', ')}');
  }
  return text;
}
