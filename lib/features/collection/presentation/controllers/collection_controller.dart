import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/collection/domain/cheque_status.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection.dart';
import 'package:sales_sphere_erp/features/collection/domain/collection_party.dart';
import 'package:sales_sphere_erp/features/collection/domain/payment_mode.dart';
import 'package:sales_sphere_erp/features/collection/presentation/providers/collection_providers.dart';

part 'collection_controller.g.dart';

/// Routes collection write actions from the UI into the in-memory store.
/// Reads stay on [collectionListProvider].
///
/// Mock-only: there's no repository / network yet, so [addCollection]
/// just stamps an id + `createdAt` onto the draft and prepends it to the
/// list. When a backend lands this gains a repository dependency and the
/// body becomes a `repo.addCollection(draft)` call.
@riverpod
class CollectionController extends _$CollectionController {
  @override
  void build() {}

  /// Persists a new collection. Mock-only: stamps an id + `createdAt`
  /// before prepending it to the list.
  Future<Collection> addCollection({
    required CollectionParty party,
    required double amount,
    required DateTime receivedDate,
    required PaymentMode paymentMode,
    String? bankName,
    String? chequeNumber,
    DateTime? chequeDate,
    ChequeStatus? chequeStatus,
    String description = '',
    List<String> imagePaths = const <String>[],
  }) async {
    final now = DateTime.now();
    final created = Collection(
      id: 'col_${now.microsecondsSinceEpoch}',
      party: party,
      amount: amount,
      receivedDate: receivedDate,
      paymentMode: paymentMode,
      bankName: bankName,
      chequeNumber: chequeNumber,
      chequeDate: chequeDate,
      chequeStatus: chequeStatus,
      description: description,
      imagePaths: imagePaths,
      createdAt: now,
    );
    ref.read(collectionListProvider.notifier).prependLocal(created);
    return created;
  }

  /// Persists edits to an existing collection. Mock-only: writes the row
  /// straight back into the in-memory list.
  Future<Collection> updateCollection(Collection collection) async {
    ref.read(collectionListProvider.notifier).replaceLocal(collection);
    return collection;
  }
}
