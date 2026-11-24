import '../../../core/network/api_client.dart' show UploadFile;
import '../../../core/network/json.dart';
import '../../../core/network/paged_result.dart';

enum WasteReason {
  damaged('damaged'),
  factoryDefect('factory_defect'),
  lostOrTheft('lost_or_theft'),
  sampleOrGift('sample_or_gift'),
  supplierReturn('supplier_return'),
  countAdjustment('count_adjustment');

  const WasteReason(this.apiValue);
  final String apiValue;

  static WasteReason fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

enum WasteStatus {
  /// Esperando que el admin lo apruebe. El stock todavía no baja.
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const WasteStatus(this.apiValue);
  final String apiValue;

  static WasteStatus fromApi(String v) => values.firstWhere((e) => e.apiValue == v);
}

class WasteReport {
  const WasteReport({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
  });

  factory WasteReport.fromJson(Json json) => WasteReport(
        id: json.str('id'),
        itemId: json.str('item_id'),
        itemName: json.str('item_name'),
        quantity: json.integer('quantity'),
        reason: WasteReason.fromApi(json.str('reason')),
        status: WasteStatus.fromApi(json.str('status')),
        note: json.strOrNull('note'),
        createdAt: json.date('created_at'),
      );

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final WasteReason reason;
  final WasteStatus status;
  final String? note;
  final DateTime createdAt;
}

class CreateWasteInput {
  const CreateWasteInput({
    required this.clientRequestId,
    required this.itemId,
    required this.quantity,
    required this.reason,
    this.note,
    this.photo,
  });

  /// UUID para `Idempotency-Key`, igual que en las ventas.
  final String clientRequestId;

  /// Solo productos sueltos; los combos no se registran como merma.
  final String itemId;
  final int quantity;
  final WasteReason reason;
  final String? note;
  final UploadFile? photo;
}

abstract interface class WasteRepository {
  /// Envía la merma al administrador. Queda `pending` hasta que la apruebe.
  Future<WasteReport> create(CreateWasteInput input);

  /// Mis mermas, de la más nueva a la más antigua.
  Future<PagedResult<WasteReport>> list({WasteStatus? status, int page = 1});
}
