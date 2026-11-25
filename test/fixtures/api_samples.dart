/// Respuestas de ejemplo del backend. Son las mismas que aparecen en
/// docs/api-contract.md: si el contrato cambia, se cambian aquí y allá.
library;

const sellerMemberJson = {
  'id': '4',
  'code': 'ALI-04',
  'name': 'Alison',
  'role': 'seller',
  'title': 'Ventas por comisión',
};

const controlMemberJson = {
  'id': '1',
  'code': 'JIM-01',
  'name': 'Jime',
  'role': 'control',
  'title': 'Control y validación',
};

const loginResponse = {
  'data': {'token': '12|k9sPq3', 'member': sellerMemberJson},
};

const secondStepResponse = {
  'data': {
    'two_factor': {
      'challenge_id': '9f3a1c',
      'expires_at': '2026-12-06T18:05:00-04:00',
      'resend_at': '2026-12-06T18:00:45-04:00',
      'code_length': 6,
    },
  },
};

const resendResponse = {
  'data': {
    'challenge_id': '71be02',
    'expires_at': '2026-12-06T18:06:00-04:00',
    'resend_at': '2026-12-06T18:01:45-04:00',
    'code_length': 6,
  },
};

const twoFactorResponse = {
  'data': {'token': '13|Zr81aa', 'member': controlMemberJson},
};

const meResponse = {
  'data': {'member': sellerMemberJson},
};

const invalidCredentialsError = {'message': 'Código o PIN incorrectos.'};

const invalidSecondStepError = {
  'message': 'El código no es correcto.',
  'code': 'two_factor_invalid',
};

const weekJson = {
  'label': '1–6 dic',
  'starts_on': '2026-12-01',
  'ends_on': '2026-12-06',
  'target': '40000.00',
  'base_prize': '1500.00',
};

/// Inicio de quien vende por comisión.
const sellerHomeResponse = {
  'data': {
    'week': weekJson,
    'collected': '41600.00',
    'fund_share_rate': '0.20',
    'kpi': {
      'score_percent': 83,
      'minimum_percent': 80,
      'compliance': 'passes',
      'deliverables': null,
      'indicators': [
        {
          'id': '41',
          'name': 'Nuevos compradores contactados',
          'target': 27,
          'actual': 25,
          'weight': '0.30',
          'evidence_status': 'validated',
        },
        {
          'id': '44',
          'name': 'Registro semanal de ventas',
          'target': 1,
          'actual': null,
          'weight': '0.10',
          'evidence_status': 'in_review',
        },
      ],
    },
    'month_commission': {'amount': '412.50', 'pay_note': null},
    'today_sales': [
      {
        'id': '1046',
        'created_at': '2026-12-06T11:09:00-04:00',
        'items_label': 'Tomatodos de Messi × 2',
        'customer_name': 'Mariela Quispe',
        'total': '174.00',
        'payment_method': 'qr',
      },
    ],
    'cash_today': null,
  },
};

/// Inicio de almacén: con caja del día y sin comisiones.
const warehouseHomeResponse = {
  'data': {
    'week': weekJson,
    'collected': '41600.00',
    'fund_share_rate': 0.2,
    'kpi': {
      'score_percent': 97,
      'minimum_percent': 90,
      'compliance': 'passes',
      'indicators': <Object>[],
    },
    'month_commission': null,
    'today_sales': <Object>[],
    'cash_today': {
      'collected': '4968.00',
      'paid_orders': 7,
      'pending_orders': 1,
      'status': 'open',
    },
  },
};

/// Inicio de Sistemas: con entregas técnicas.
const systemsHomeResponse = {
  'data': {
    'week': weekJson,
    'collected': '41600.00',
    'fund_share_rate': '0.10',
    'kpi': {
      'score_percent': 100,
      'minimum_percent': 90,
      'compliance': 'pending',
      'deliverables': {'approved': 2, 'total': 4},
      'closed_reason': null,
      'indicators': <Object>[],
    },
  },
};

const controlSummaryResponse = {
  'data': {
    'as_of': '2026-12-06T18:00:00-04:00',
    'week': weekJson,
    'collected': '41600.00',
    'pending': {'payments': 3, 'evidence': 2, 'cash_closings': 1, 'deliverables': 1},
    'members': [
      {
        'id': '5',
        'name': 'Kim',
        'score_percent': 85,
        'minimum_percent': 90,
        'compliance': 'fails',
        'fund_share_rate': '0.20',
        'note': null,
      },
      {
        'id': '6',
        'name': 'Sistemas 1',
        'score_percent': 100,
        'minimum_percent': 90,
        'compliance': 'pending',
        'fund_share_rate': '0.10',
        'note': '2 de 4 entregas validadas',
      },
    ],
    'bonus': {
      'level': 'complete',
      'prize': '1500.00',
      'payable': '1050.00',
      'unpaid_failing': '300.00',
      'unpaid_pending': '150.00',
    },
  },
};
