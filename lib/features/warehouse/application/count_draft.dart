import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/application/session_controller.dart';
import '../../catalog/domain/catalog.dart';

@immutable
class CountDraftItem {
  const CountDraftItem({
    required this.productId,
    required this.itemCode,
    required this.name,
    this.counted,
  });

  final String productId;
  final String itemCode;
  final String name;

  /// `null` mientras no se escriba lo contado.
  final int? counted;
}

/// El conteo que se está haciendo. Se conserva al buscar productos o cambiar de
/// pestaña y se descarta si entra otra persona.
@immutable
class CountDraft {
  const CountDraft({required this.requestKey, this.items = const []});

  final String requestKey;
  final List<CountDraftItem> items;

  bool contains(String productId) => items.any((i) => i.productId == productId);

  int get missing => items.where((i) => i.counted == null).length;

  String? get blockedReason {
    if (items.isEmpty) return 'Agrega productos';
    if (missing > 0) return missing == 1 ? 'Falta contar 1' : 'Faltan contar $missing';
    return null;
  }
}

final countDraftProvider =
    NotifierProvider<CountDraftController, CountDraft>(CountDraftController.new);

class CountDraftController extends Notifier<CountDraft> {
  static const _uuid = Uuid();

  @override
  CountDraft build() {
    ref.watch(sessionMemberIdProvider);
    return CountDraft(requestKey: _uuid.v4());
  }

  void add(CatalogItem item) {
    if (state.contains(item.id)) return;
    _change([
      ...state.items,
      CountDraftItem(productId: item.id, itemCode: item.itemCode, name: item.name),
    ]);
  }

  void setCounted(String productId, int? counted) => _change([
        for (final i in state.items)
          i.productId == productId
              ? CountDraftItem(
                  productId: i.productId,
                  itemCode: i.itemCode,
                  name: i.name,
                  counted: counted,
                )
              : i,
      ]);

  void remove(String productId) =>
      _change([...state.items.where((i) => i.productId != productId)]);

  void reset() => state = CountDraft(requestKey: _uuid.v4());

  /// Cambiar lo que se envía hace otro envío.
  void _change(List<CountDraftItem> items) =>
      state = CountDraft(requestKey: _uuid.v4(), items: items);
}
