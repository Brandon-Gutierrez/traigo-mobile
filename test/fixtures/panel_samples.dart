/// Ejemplos del panel de Jime y de Dirección (docs/api-contract.md).
library;

import 'team_samples.dart' show evidenceJson, numberedWeekJson;

const pendingResponse = {
  'data': [
    {
      'type': 'cash_closing',
      'id': 'cc-5',
      'title': 'Isaí · cierre del sábado 5 dic',
      'subtitle': 'Efectivo, QR y transferencia',
      'created_at': '2026-12-05T18:30:00-04:00',
      'amount': '7670.00',
    },
    {
      'type': 'payment',
      'id': 'pay-9',
      'title': 'Rosa Mamani · Alison',
      'subtitle': 'QR',
      'created_at': '2026-12-06T10:48:00-04:00',
      'amount': '90.00',
    },
  ],
};

const paymentReviewJson = {
  'id': 'pay-9',
  'order': {
    'id': 'o-1052',
    'number': 'N-1052',
    'customer_name': 'Rosa Mamani',
    'seller_name': 'Alison',
    'items_label': 'Maceta tipo cemento pequeño × 3',
    'total': '90.00',
  },
  'method': 'qr',
  'amount': '90.00',
  'status': 'submitted',
  'reference': '0045-8812',
  'reference_unique': true,
  'proof_url': 'https://res.cloudinary.com/traigo/comprobante-1052.jpg',
  'submitted_at': '2026-12-06T10:48:00-04:00',
  'destination_account': 'Traigo',
  'reject_reason': null,
};

const paymentReviewResponse = {'data': paymentReviewJson};

const confirmPaymentRequest = {
  'amount_matches': true,
  'destination_ok': true,
  'received_at': null,
};

const evidenceReviewResponse = {
  'data': {
    'result_id': 'r-44',
    'member': {'id': 'm-4', 'name': 'Alison'},
    'week_label': '1–6 dic',
    'indicator': {
      'id': 'r-44',
      'name': 'Registro semanal de ventas',
      'how_verified': 'Pedidos, clientes y evidencias de cobro',
      'unit': 'count',
      'target': 1,
      'actual': null,
      'weight': '0.10',
      'evidence_status': 'in_review',
    },
    'evidence': [evidenceJson],
  },
};

const complianceResponse = {
  'data': [
    {
      'id': 'm-6',
      'name': 'Sistemas 1',
      'title': 'Sistemas',
      'score_percent': 100,
      'partial_score_percent': 100,
      'minimum_percent': 90,
      'compliance': 'pending',
      'indicators_loaded': 5,
      'indicators_total': 5,
      'deliverables_on_time': 2,
      'deliverables_total': 4,
      'closed_reason': null,
    },
    {
      'id': 'm-5',
      'name': 'Kim',
      'title': 'Ventas mayoristas',
      'score_percent': 85,
      'partial_score_percent': 85,
      'minimum_percent': 90,
      'compliance': 'fails',
      'indicators_loaded': 6,
      'indicators_total': 6,
      'deliverables_on_time': null,
      'deliverables_total': null,
      'closed_reason': null,
    },
  ],
};

const weeklyClosingResponse = {
  'data': {
    'week': numberedWeekJson,
    'status': 'open',
    'checks': {
      'payments_reconciled': {'ok': true, 'detail': '34 de 34 pagos confirmados'},
      'kpi_evidence': {'ok': true, 'detail': '6 de 6 personas con evidencia validada'},
      'duplicates_cleared': {'ok': true, 'detail': '1 duplicado quitado (N-1049)'},
      'direction_approval': {'ok': false, 'detail': 'Falta su aprobación'},
    },
    'pending_members': [
      {'id': 'm-6', 'name': 'Sistemas 1', 'pending_reason': '2 de 4 entregas validadas'},
    ],
    'observations': null,
    'return_reason': null,
  },
};

const sendClosingRequest = {
  'payments_reconciled': true,
  'kpi_evidence_ok': true,
  'duplicates_cleared': true,
  'close_pending': [
    {'member_id': 'm-6', 'reason': 'Solo 2 de sus 4 entregas quedaron validadas.'},
  ],
  'observations': null,
};

const bonusResponse = {
  'data': {
    'week': numberedWeekJson,
    'status': 'sent',
    'collected': '41600.00',
    'achievement_percent': 104,
    'tier': 'complete',
    'release_factor': '1.00',
    'fund': '1500.00',
    'payable': '1050.00',
    'unpaid': '450.00',
    'members': [
      {
        'id': 'm-2',
        'name': 'Ailén',
        'fund_share_rate': '0.20',
        'compliance': 'passes',
        'share_amount': '300.00',
        'amount': '300.00',
        'paid_at': null,
        'closed_reason': null,
      },
      {
        'id': 'm-6',
        'name': 'Sistemas 1',
        'fund_share_rate': '0.10',
        'compliance': 'fails',
        'share_amount': '150.00',
        'amount': '0.00',
        'paid_at': null,
        'closed_reason': 'Solo 2 de sus 4 entregas quedaron validadas.',
      },
    ],
  },
};

const commissionsResponse = {
  'data': {
    'month': '2026-12',
    'status': 'open',
    'rates_pending': true,
    'total': null,
    'settles_on': '2026-12-31',
    'return_reason': null,
    'members': [
      {
        'id': 'm-4',
        'name': 'Alison',
        'amount': null,
        'paid_sales': 11,
        'adjustments': '0.00',
      },
      {
        'id': 'm-5',
        'name': 'Kim',
        'amount': null,
        'paid_sales': 5,
        'adjustments': '-45.00',
      },
    ],
  },
};

const priceSheetResponse = {
  'data': {
    'product_id': 'p-8107',
    'item_code': '8107',
    'name': 'Tomatodos de Messi',
    'category': 'Tomatodos',
    'current': {
      'price_unit': '87.00',
      'price_wholesale': '82.00',
      'wholesale_min_qty': 24,
      'commission_pct': null,
      'cost': null,
    },
    'pending_change': {
      'id': 'pc-1',
      'proposed': {'price_unit': '89.00', 'price_wholesale': '84.00'},
      'requested_by': 'Jime',
      'requested_at': '2026-12-06T11:00:00-04:00',
      'reason': null,
    },
  },
};

const priceChangeRequest = {
  'price_unit': '89.00',
  'price_wholesale': '84.00',
  'reason': null,
};

const auditResponse = {
  'data': [
    {
      'id': '812',
      'at': '2026-12-06T10:42:00-04:00',
      'actor_name': 'Jime',
      'description': 'Cargó el valor real de «Registro semanal de ventas» de Alison: sin cargar → 1',
    },
  ],
  'meta': {'current_page': 1, 'last_page': 3, 'per_page': 30, 'total': 72},
};

const systemStatusResponse = {
  'data': {
    'last_backup_at': '2026-12-06T03:00:00-04:00',
    'restore_tested_at': '2026-11-29T16:00:00-04:00',
  },
};

const authorizationItemJson = {
  'type': 'weekly_bonus',
  'id': '1',
  'title': 'Bono semana 1–6 dic',
  'requested_by': 'Jime',
  'requested_at': '2026-12-06T11:02:00-04:00',
  'amount': '1050.00',
};

const authorizationsResponse = {
  'data': [authorizationItemJson],
};

const authorizationDetailResponse = {
  'data': {
    ...authorizationItemJson,
    'pays': [
      {'name': 'Ailén', 'amount': '300.00'},
      {'name': 'Sistemas 2', 'amount': '150.00'},
    ],
    'unpaid': [
      {'name': 'Kim', 'amount': '300.00', 'reason': 'KPI 85 % de 90 %'},
      {
        'name': 'Sistemas 1',
        'amount': '150.00',
        'reason': 'Cerrado por Jime: solo 2 de sus 4 entregas quedaron validadas.',
      },
    ],
    'checks': ['Cobros conciliados: 34 de 34', 'KPI con evidencia validada'],
    'changes': <Object>[],
    'can_approve': true,
    'blocked_reason': null,
  },
};
