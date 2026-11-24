/// Rutas de la API, relativas a `API_BASE_URL` (que ya incluye `/api/v1`).
/// Cada una está explicada en docs/api-contract.md.
abstract final class ApiPaths {
  // Auth
  static const login = '/auth/login';
  static const logout = '/auth/logout';
  static const me = '/me';

  // Inicio
  static const home = '/home';

  // Catálogo (productos y combos)
  static const catalog = '/catalog';
  static const categories = '/catalog/categories';
  static String catalogItem(String kind, String id) => '/catalog/$kind/$id';

  // Pedidos (ventas del vendedor)
  static const orders = '/orders';
  static String order(String id) => '/orders/$id';
  static String orderCancel(String id) => '/orders/$id/cancel';
  static String orderPaymentProof(String id) => '/orders/$id/payment-proof';

  // Stock
  static const stockSummary = '/stock/summary';
  static const stockMovements = '/stock/movements';

  // Mermas
  static const waste = '/waste';
}
