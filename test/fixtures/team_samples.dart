/// Ejemplos de equipo, «Mi semana», caja e inventario (docs/api-contract.md).
library;

import 'api_samples.dart' show weekJson;

const numberedWeekJson = {'number': 1, ...weekJson};

const teamWeekResponse = {
  'data': {
    'week': weekJson,
    'collected': '31200.00',
    'tiers': [
      {
        'tier': 'partial',
        'threshold_percent': 90,
        'sales_needed': '36000.00',
        'fund': '750.00',
        'my_share': '150.00',
      },
      {
        'tier': 'complete',
        'threshold_percent': 100,
        'sales_needed': '40000.00',
        'fund': '1500.00',
        'my_share': '300.00',
      },
      {
        'tier': 'superior',
        'threshold_percent': 115,
        'sales_needed': '46000.00',
        'fund': '1875.00',
        'my_share': '375.00',
      },
    ],
    'me': {
      'fund_share_rate': '0.20',
      'minimum_percent': 80,
      'partial_score_percent': 68,
      'compliance': 'pending',
    },
    'weeks': [
      {'number': 1, ...weekJson, 'is_current': true},
      {
        'number': 2,
        'label': '7–13 dic',
        'starts_on': '2026-12-07',
        'ends_on': '2026-12-13',
        'target': '60000.00',
        'base_prize': '2500.00',
        'is_current': false,
      },
    ],
  },
};

const evidenceJson = {
  'id': 'ev-1',
  'kind': 'photo',
  'status': 'in_review',
  'url': 'https://res.cloudinary.com/traigo/registro-ventas.jpg',
  'order_id': null,
  'order_number': null,
  'note': 'Incluye las 4 ventas cobradas del lunes',
  'submitted_at': '2026-12-06T09:40:00-04:00',
  'review_note': null,
};

const deliverableJson = {
  'id': 'd-1',
  'title': 'Tienda web publicada, navegable y con catálogo',
  'acceptance_test': 'Acceso público; categorías, precios y ficha de producto',
  'due_on': '2026-11-30',
  'status': 'on_time',
  'member_id': 'm-6',
  'member_name': 'Sistemas 1',
  'delivered_on': '2026-11-30',
  'evidence_url': 'https://res.cloudinary.com/traigo/tienda.png',
  'review_note': null,
};

const myWeekResponse = {
  'data': {
    'week': numberedWeekJson,
    'count_target_factor': '0.90',
    'score_percent': null,
    'partial_score_percent': 68,
    'minimum_percent': 80,
    'compliance': 'pending',
    'indicators': [
      {
        'id': 'r-44',
        'name': 'Registro semanal de ventas',
        'how_verified': 'Pedidos, clientes y evidencias de cobro',
        'unit': 'count',
        'target': 1,
        'actual': null,
        'weight': '0.10',
        'evidence_status': 'in_review',
        'evidence': [evidenceJson],
      },
    ],
    'deliverables': <Object>[],
    'accepts_evidence': true,
    'closed_reason': null,
  },
};

const evidenceResponse = {'data': evidenceJson};

const deliverableResponse = {'data': deliverableJson};

const cashDayJson = {
  'closing_id': 'cc-1',
  'business_date': '2026-12-01',
  'status': 'sent',
  'collected': '4968.00',
  'paid_orders': 7,
  'pending_orders': 1,
  'lines': [
    {
      'method': 'qr',
      'orders_count': 4,
      'expected': '2140.00',
      'counted': '2140.00',
      'note': null,
    },
    {
      'method': 'cash',
      'orders_count': 2,
      'expected': '860.00',
      'counted': '810.00',
      'note': null,
    },
  ],
  'pending': [
    {
      'order_id': 'o-1047',
      'number': 'N-1047',
      'customer_name': 'Pedro Alanoca',
      'payment_method': 'qr',
      'total': '350.00',
      'seller_name': 'Alison',
      'detail': 'sin comprobante',
    },
  ],
  'pending_days': [
    {'date': '2026-11-30', 'status': 'observed'},
  ],
  'closed_by_name': 'Isaí',
  'sent_at': '2026-12-01T18:30:00-04:00',
  'note': 'Faltan Bs 50 de cambio, se revisa mañana.',
  'review_note': null,
};

const cashDayResponse = {'data': cashDayJson};

const cashClosingRequest = {
  'business_date': '2026-12-01',
  'lines': [
    {'method': 'qr', 'counted': '2140.00'},
    {'method': 'cash', 'counted': '810.00'},
  ],
  'note': 'Faltan Bs 50 de cambio, se revisa mañana.',
};

const inventoryCountJson = {
  'id': 'ic-1',
  'counted_on': '2026-12-04',
  'items': [
    {
      'product_id': 'p-8109',
      'item_code': '8109',
      'name': 'Tomatodos de Ronaldo',
      'system_qty': 38,
      'counted_qty': 36,
      'adjusted': false,
    },
  ],
};

const inventoryCountsResponse = {
  'data': [inventoryCountJson],
};

const inventoryCountResponse = {'data': inventoryCountJson};

const inventoryCountRequest = {
  'counted_on': '2026-12-04',
  'items': [
    {'product_id': 'p-8109', 'counted_qty': 36},
  ],
  'note': null,
};

const dispatchesResponse = {
  'data': [
    {
      'order_id': 'o-1043',
      'number': 'N-1043',
      'customer_name': 'Comercio El Hogar',
      'items_label': 'Tomatodos de Ronaldo × 24',
      'lines': [
        {'item_code': '8109', 'name': 'Tomatodos de Ronaldo', 'quantity': 24},
      ],
      'delivery_type': 'delivery',
      'status': 'paid',
      'is_late': false,
      'customer_phone': '71234567',
      'shipping_address': 'Av. Blanco Galindo km 4, Cochabamba',
      'paid_at': '2026-12-05T16:10:00-04:00',
      'promised_at': '2026-12-06T18:00:00-04:00',
    },
  ],
};

const stockEntryRequest = {
  'product_id': 'p-8109',
  'type': 'adjustment_out',
  'quantity': -2,
  'note': 'Conteo del viernes',
  'inventory_count_id': 'ic-1',
};

const stockLevelResponse = {
  'data': {'product_id': 'p-8109', 'stock': 36, 'reserved': 0, 'available': 36},
};

const returnOrderRequest = {'reason': 'Llegó golpeado'};

const duplicateOrderRequest = {'original_order_id': 'o-1048'};
