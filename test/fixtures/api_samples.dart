/// Respuestas de ejemplo del backend. Son las mismas que aparecen en
/// docs/api-contract.md: si el contrato cambia, se cambian aquí y allá.
library;

const sellerJson = {'id': '1', 'code': 'ANA-07', 'name': 'Ana López'};
const rulesJson = {'personal_rate': '0.40', 'fund_rate': '0.25'};

const loginResponse = {
  'data': {'token': '1|k9sPq3', 'seller': sellerJson, 'rules': rulesJson},
};

const meResponse = {
  'data': {'seller': sellerJson, 'rules': rulesJson},
};

const catalogPage = {
  'data': [
    {
      'id': '1',
      'kind': 'product',
      'code': 'TR-0151',
      'name': 'Audífonos bluetooth ANC con estuche',
      'category': 'Audio',
      'image_url': null,
      'suggested_price': '120.00',
      'min_price': '90.00',
      'stock': 34,
      'low_stock_alert': 10,
      'components': [],
    },
    {
      'id': '1',
      'kind': 'combo',
      'code': 'CMB-01',
      'name': 'Combo Escritorio Pro',
      'category': 'Combos',
      'image_url': null,
      'suggested_price': '199.00',
      'min_price': '191.00',
      'stock': 12,
      'low_stock_alert': 5,
      'components': [
        {'name': 'Lámpara luna LED recargable', 'quantity': 1},
        {'name': 'Audífonos bluetooth ANC con estuche', 'quantity': 1},
        {'name': 'Organizador plegable multiuso', 'quantity': 1},
      ],
    },
  ],
  'meta': {'current_page': 1, 'last_page': 5, 'per_page': 30, 'total': 124},
};

const orderDetailResponse = {
  'data': {
    'id': '131',
    'number': '131',
    'created_at': '2026-11-23T11:20:00-04:00',
    'customer_name': 'Mariela Quispe',
    'items_label': 'Combo Escritorio Pro',
    'total': '199.00',
    'payment_method': 'qr',
    'status': 'pending_payment',
    'commission': {'amount': '3.20', 'state': 'pending'},
    'customer_whatsapp': '71234567',
    'delivery': {'type': 'delivery', 'address': 'Av. Blanco Galindo km 4', 'city': null},
    'lines': [
      {
        'kind': 'combo',
        'item_id': '1',
        'code': 'CMB-01',
        'name': 'Combo Escritorio Pro',
        'quantity': 1,
        'unit_price': '199.00',
        'min_price': '191.00',
      },
    ],
    'breakdown': {'gain': '8.00', 'personal': '3.20', 'fund': '2.00'},
    'payment_proof': {
      'status': 'uploaded',
      'url': 'https://api.traigo.bo/storage/proofs/131.jpg',
      'uploaded_at': '2026-11-23T11:25:00-04:00',
      'rejection_reason': null,
    },
    'timeline': [
      {'key': 'registered', 'at': '2026-11-23T11:20:00-04:00'},
      {'key': 'payment_confirmed', 'at': null},
      {'key': 'delivered', 'at': null},
    ],
  },
};

const ordersPage = {
  'data': [
    {
      'id': '131',
      'number': '131',
      'created_at': '2026-11-23T11:20:00-04:00',
      'customer_name': 'Mariela Quispe',
      'items_label': 'Combo Escritorio Pro',
      'total': '199.00',
      'payment_method': 'qr',
      'status': 'pending_payment',
      'commission': {'amount': '3.20', 'state': 'pending'},
    },
  ],
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
};

const homeResponse = {
  'data': {
    'today': {'commission': '86.40', 'sales_count': 5, 'sold_total': '1080.00'},
    'month': {
      'personal_commission': '1340.00',
      'fund_share': '643.33',
      'estimated_total': '1983.33',
    },
    'fund': {'current': '3860.00', 'goal': '5000.00', 'prize_label': null},
    'payout_note': null,
    'recent_orders': [
      {
        'id': '131',
        'number': '131',
        'created_at': '2026-11-23T11:20:00-04:00',
        'customer_name': 'Mariela Quispe',
        'items_label': 'Combo Escritorio Pro',
        'total': '199.00',
        'payment_method': 'qr',
        'status': 'pending_payment',
        'commission': {'amount': '3.20', 'state': 'pending'},
      },
    ],
  },
};

const stockSummaryResponse = {
  'data': {
    'products_total': 124,
    'low_count': 2,
    'out_count': 1,
    'attention_items': [
      {
        'id': '3',
        'kind': 'product',
        'code': 'TR-0133',
        'name': 'Termo digital 500 ml',
        'category': 'Cocina',
        'image_url': null,
        'suggested_price': '75.00',
        'min_price': '48.00',
        'stock': 3,
        'low_stock_alert': 10,
        'components': [],
      },
    ],
  },
};

const movementsPage = {
  'data': [
    {
      'id': '901',
      'occurred_at': '2026-11-23T11:20:00-04:00',
      'quantity_delta': -1,
      'item_name': 'Combo Escritorio Pro',
      'description': 'Venta #131 de Ana',
      'type': 'sale',
      'pending': false,
    },
  ],
  'meta': {'current_page': 1, 'last_page': 1, 'per_page': 20, 'total': 1},
};

const wasteResponse = {
  'data': {
    'id': '19',
    'item_id': '3',
    'item_name': 'Termo digital 500 ml',
    'quantity': 1,
    'reason': 'damaged',
    'status': 'pending',
    'note': 'Se cayó del estante',
    'created_at': '2026-11-23T09:12:00-04:00',
  },
};

// Errores
const invalidCredentialsError = {'message': 'Código o PIN incorrectos.'};

const priceBelowMinimumError = {
  'message': 'No puedes vender Audífonos bluetooth ANC con estuche por debajo de Bs 90.',
  'code': 'price_below_minimum',
  'errors': {
    'lines.0.unit_price': ['El precio mínimo es Bs 90.'],
  },
  'data': {'kind': 'product', 'item_id': '1', 'min_price': '90.00'},
};

const insufficientStockError = {
  'message': 'Solo quedan 3 de Termo digital 500 ml.',
  'code': 'insufficient_stock',
  'data': {'kind': 'product', 'item_id': '3', 'available': 3},
};

const notCancellableError = {
  'message': 'Este pedido ya no se puede cancelar porque el pago fue confirmado.',
  'code': 'not_cancellable',
};
