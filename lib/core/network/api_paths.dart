/// Rutas de la API, relativas a `API_BASE_URL` (que ya incluye `/api/v1`).
/// Cada una está explicada en docs/api-contract.md.
abstract final class ApiPaths {
  // Ingreso
  static const login = '/auth/login';
  static const twoFactor = '/auth/two-factor';
  static const twoFactorResend = '/auth/two-factor/resend';
  static const logout = '/auth/logout';
  static const me = '/me';

  // Inicio y equipo
  static const home = '/home';
  static const teamWeek = '/team/week';
  static const myWeek = '/me/week';
  static String myEvidence(String resultId) => '/me/kpi-results/$resultId/evidence';
  static String myDeliverable(String id) => '/me/deliverables/$id/submission';

  // Catálogo y ventas
  static const catalog = '/catalog';
  static const catalogCategories = '/catalog/categories';
  static String catalogItem(String id) => '/catalog/$id';
  static const orders = '/orders';
  static String order(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderPaymentProof(String id) => '/orders/$id/payment-proof';

  // Almacén
  static const cashToday = '/cash/today';
  static const cashClosings = '/cash/closings';
  static const inventoryCounts = '/inventory/counts';
  static const stockMovements = '/inventory/movements';
  static const dispatches = '/warehouse/dispatches';
  static String dispatchReady(String orderId) => '/warehouse/orders/$orderId/ready';
  static String dispatchDelivered(String orderId) =>
      '/warehouse/orders/$orderId/delivered';

  // Panel de Jime y Dirección
  static const controlSummary = '/control/summary';
  static const controlPending = '/control/pending';
  static String controlOrderReturn(String id) => '/control/orders/$id/return';
  static String controlOrderDuplicate(String id) => '/control/orders/$id/duplicate';
  static String controlPayment(String id) => '/control/payments/$id';
  static String controlPaymentConfirm(String id) => '/control/payments/$id/confirm';
  static String controlPaymentReject(String id) => '/control/payments/$id/reject';
  static String controlKpiResult(String id) => '/control/kpi-results/$id';
  static String controlKpiValidate(String id) => '/control/kpi-results/$id/validate';
  static String controlKpiObserve(String id) => '/control/kpi-results/$id/observe';
  static String controlCashClosing(String id) => '/control/cash-closings/$id';
  static String controlCashValidate(String id) => '/control/cash-closings/$id/validate';
  static String controlCashObserve(String id) => '/control/cash-closings/$id/observe';
  static const controlDeliverables = '/control/deliverables';
  static String controlDeliverableValidate(String id) =>
      '/control/deliverables/$id/validate';
  static String controlDeliverableReject(String id) => '/control/deliverables/$id/reject';
  static const controlCompliance = '/control/compliance';
  static const controlWeeklyClosing = '/control/weekly-closing';
  static String controlWeeklyClosingSend(int week) => '/control/weekly-closing/$week/send';
  static const controlBonus = '/control/bonus';
  static String controlBonusPaid(int week, String memberId) =>
      '/control/bonus/$week/members/$memberId/paid';
  static const controlCommissions = '/control/commissions';
  static String controlCommissionsSend(String month) => '/control/commissions/$month/send';
  static String controlCommissionsPaid(String month) => '/control/commissions/$month/paid';
  static String controlProduct(String id) => '/control/products/$id';
  static String controlPriceChanges(String id) => '/control/products/$id/price-changes';
  static const controlAudit = '/control/audit';
  static String controlReport(String type) => '/control/reports/$type';
  static const controlSystemStatus = '/control/system-status';
  static String controlMemberPin(String id) => '/control/members/$id/pin';
  static String controlMemberRevoke(String id) => '/control/members/$id/revoke-sessions';

  // Autorizaciones de Dirección
  static const authorizations = '/management/authorizations';
  static String authorization(String type, String id) =>
      '/management/authorizations/$type/$id';
  static String authorizationApprove(String type, String id) =>
      '/management/authorizations/$type/$id/approve';
  static String authorizationReturn(String type, String id) =>
      '/management/authorizations/$type/$id/return';
}
