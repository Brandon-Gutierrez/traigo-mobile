/// Ejemplos de catálogo y ventas. Son los mismos de docs/api-contract.md (el
/// documento se genera con ellos: `dart tool/build_contract.dart`).
library;

const catalogItemJson = {
  'id': '0b9a6f3c-1d2e-4f5a-8b7c-9d0e1f2a3b4c',
  'item_code': '8107',
  'name': 'Tomatodos de Messi',
  'category': 'Tomatodos',
  'price_unit': '87.00',
  'price_wholesale': '82.00',
  'wholesale_min_qty': 24,
  'stock': 48,
  'reserved': 3,
  'available': 45,
  'commission_pct': null,
  'image_url': null,
};

const catalogResponse = {
  'data': [catalogItemJson],
  'meta': {
    'current_page': 1,
    'last_page': 1,
    'per_page': 30,
    'total': 1,
  },
};

const categoriesResponse = {
  'data': [
    {'id': 'c1', 'name': 'Tomatodos', 'count': 9},
    {'id': 'c2', 'name': 'Macetas', 'count': 36},
    {'id': 'c3', 'name': 'Juguetes', 'count': 17},
  ],
};

const catalogDetailResponse = {
  'data': {
    ...catalogItemJson,
    'description': null,
    'images': <String>[],
  },
};

const orderSummaryJson = {
  'id': 'o-1046',
  'number': 'N-1046',
  'created_at': '2026-12-06T11:09:00-04:00',
  'customer_name': 'Mariela Quispe',
  'items_label': 'Tomatodos de Messi × 2',
  'total': '174.00',
  'payment_method': 'qr',
  'status': 'payment_review',
};

const ordersResponse = {
  'data': [orderSummaryJson],
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
};

const newSaleRequest = {
  'origin': 'wholesale',
  'customer': {'name': 'Comercio El Hogar', 'phone': '71234567'},
  'delivery': {
    'type': 'pickup',
    'address': null,
    'promised_at': '2026-12-06T18:00:00-04:00',
  },
  'payment_method': 'transfer',
  'lines': [
    {'product_id': 'p-8107', 'quantity': 24},
    {'product_id': 'p-1109', 'quantity': 10},
  ],
  'expected_total': '2268.00',
};

/// Lo común de un pedido abierto, sin lo que cambia según quién lo mira.
const orderDetailBodyJson = {
  ...orderSummaryJson,
  'origin': 'whatsapp',
  'customer_phone': '71234567',
  'delivery': {
    'type': 'pickup',
    'address': null,
    'promised_at': '2026-12-06T18:00:00-04:00',
  },
  'lines': [
    {
      'product_id': 'p-8107',
      'item_code': '8107',
      'name': 'Tomatodos de Messi',
      'category': 'Tomatodos',
      'image_url': null,
      'quantity': 2,
      'price_type': 'unit',
      'unit_price': '87.00',
      'line_total': '174.00',
    },
  ],
  'payment': {
    'method': 'qr',
    'status': 'submitted',
    'reference': null,
    'proof_url': 'https://res.cloudinary.com/traigo/comprobante-1046.jpg',
    'submitted_at': '2026-12-06T11:25:00-04:00',
    'reject_reason': null,
  },
  'timeline': [
    {'status': 'pending_payment', 'at': '2026-12-06T11:09:00-04:00'},
    {'status': 'paid', 'at': null},
    {'status': 'ready', 'at': null},
    {'status': 'delivered', 'at': null},
  ],
};

const orderDetailJson = {
  ...orderDetailBodyJson,
  'commission': {'status': 'pending', 'amount': null},
  'can_cancel': true,
  'can_upload_proof': true,
};

const orderDetailResponse = {'data': orderDetailJson};

const priceChangedError = {
  'message': 'Los precios cambiaron. Revisa el total antes de registrar.',
  'code': 'price_changed',
  'data': {'total': '2278.00'},
};

const insufficientStockError = {
  'message': 'Solo quedan 3 de Tomatodos de Messi.',
  'code': 'insufficient_stock',
  'data': {'product_id': 'p-8107', 'available': 3},
};
