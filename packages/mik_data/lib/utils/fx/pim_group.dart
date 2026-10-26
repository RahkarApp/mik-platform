import 'package:mik_data/utils/saveHelper.dart';
import 'package:uuid/uuid.dart';

import '../../source/remote/auth_error.dart';
import '../../source/remote/models/models.dart';
import '../../source/remote/pim_group_store.dart';
import 'pim.dart';

class PimGroupFX {
  static final _groups = Expando<PimGroupFX>();
  static PimGroupFX forProducts(PimFX products) =>
      _groups[products] ??= PimGroupFX(products);
  final PimFX products;
  final PimGroupStore store;
  Future<void> _writes = Future.value();
  Future<void>? _saving;
  PimGroupFX(this.products, {this.store = const SecurePimGroupStore()});
  String get key =>
      'pim.group.v1.${products.context.auth.appId}.${products.context.origin}.${products.context.session.identityId}.${products.businessId}';

  Future<PimGroupState> read() async {
    await _writes;
    products.context.check();
    final state = await store.read(key);
    products.context.check();
    return state;
  }

  Future<void> _update(Future<void> Function() action) {
    final next = _writes.then((_) => action(), onError: (_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> updateDrafts(
    List<PimProductDraft> Function(List<PimProductDraft>) update,
  ) => _update(() async {
    products.context.check();
    final state = await store.read(key);
    if (state.pending) throw const AuthError(409, 'PIM_PENDING');
    await store.write(key, PimGroupState(drafts: update(state.drafts)));
  });
  Future<void> add(String name) => updateDrafts(
    (drafts) => [...drafts, PimProductDraft(id: const Uuid().v4(), name: name)],
  );
  Future<void> rename(String before, String after) => updateDrafts(
    (drafts) => drafts
        .map((draft) => draft.name == before ? draft.rename(after) : draft)
        .toList(),
  );
  Future<void> remove(String name) => updateDrafts(
    (drafts) => drafts.where((draft) => draft.name != name).toList(),
  );
  Future<void> clear() => updateDrafts((_) => []);
  Future<void> remember(List<PimProductDraft> drafts) => updateDrafts(
    (saved) => [
      for (final draft in saved)
        drafts.any((value) => value.id == draft.id)
            ? drafts.firstWhere((value) => value.id == draft.id)
            : draft,
      ...drafts.where((draft) => !saved.any((value) => value.id == draft.id)),
    ],
  );

  Future<void> save(List<PimProductDraft> drafts) =>
      _saving ??= _update(() => _save(drafts))
          .whenComplete(() => _saving = null);
  Future<void> _save(List<PimProductDraft> drafts) async {
    products.context.check();
    var state = await store.read(key);
    if (!state.pending) {
      if (await products.restore() != null) {
        throw const AuthError(409, 'PIM_PENDING');
      }
      if (drafts.isEmpty) throw const AuthError(400, 'VALIDATION_FAILED');
      products.require('pim.product.create');
      for (final draft in drafts) {
        if (draft.prices.isNotEmpty) products.require('pim.price.create');
        for (final price in draft.prices) {
          if (price.name.trim().isEmpty ||
              price.amount == null ||
              price.amount! < 0 ||
              price.amount! > 9000000000000) {
            throw const AuthError(400, 'VALIDATION_FAILED');
          }
        }
        if (draft.prices.any((price) => price.isDefault)) {
          products.require('pim.price.default.update');
        }
        if (draft.barcode?.isNotEmpty == true) {
          products.require('pim.variant.update');
          if ((draft.fields['variantAxes'] as List? ?? []).isNotEmpty) {
            throw const AuthError(400, 'VALIDATION_FAILED');
          }
        }
      }
      final ids = drafts.map((draft) => draft.id).toSet();
      state = PimGroupState(
        drafts: [
          ...state.drafts.where((draft) => !ids.contains(draft.id)),
          ...drafts,
        ],
        steps: [
          for (final draft in drafts)
            PimGroupStep(
              draftId: draft.id,
              command: products.change(PimResource.products, {
                ...draft.fields,
                'name': draft.name,
                'status': 'DRAFT',
              }),
            ),
        ],
      );
      for (final step in state.steps) {
        products.checkCommand(step.command);
      }
      await store.write(key, state);
    }
    while (state.next < state.steps.length) {
      products.context.check();
      final step = state.steps[state.next];
      final PimResult result;
      try {
        result = await SaveHelper.savePim(products, step.command);
      } on AuthError {
        // A definitive rejection before any product was created can be edited.
        if (state.next == 0 && products.pending == null) {
          await store.write(key, PimGroupState(drafts: state.drafts));
        }
        rethrow;
      }
      // An accepted HTTP response alone must not mark an unconfirmed activation complete.
      if (step.command.resource == PimResource.products &&
          step.command.operation == 'update' &&
          step.command.body['status'] == 'ACTIVE' &&
          result.item?.status != 'ACTIVE') {
        throw const FormatException('Product activation was not confirmed');
      }
      final steps = [...state.steps];
      if (step.command.resource == PimResource.products &&
          step.command.operation == 'create') {
        final draft = state.drafts.firstWhere(
          (draft) => draft.id == step.draftId,
        );
        final item = result.item as PimProduct;
        final axes = draft.fields['variantAxes'] as List? ?? [];
        final generate =
            axes.isNotEmpty &&
            products.has('pim.variant.create') &&
            products.has('pim.variant.read');
        if (generate) {
          steps.add(
            PimGroupStep(
              draftId: draft.id,
              command: PimCommand(
                operation: 'variants/generate',
                body: {'productId': item.id},
              ),
            ),
          );
        }
        if (draft.barcode?.isNotEmpty == true) {
          final variant = result.baseVariant;
          if (variant == null) {
            throw const FormatException('Missing base variant');
          }
          steps.add(
            PimGroupStep(
              draftId: draft.id,
              command: PimCommand(
                resource: PimResource.variants,
                operation: 'update',
                id: variant.id,
                body: {
                  'barcodes': [draft.barcode!],
                  'expectedRevision': variant.revision,
                },
              ),
            ),
          );
        }
        for (final price in draft.prices) {
          steps.add(
            PimGroupStep(
              draftId: draft.id,
              command: PimCommand(
                resource: PimResource.prices,
                operation: 'create',
                body: {
                  'productId': item.id,
                  'name': price.name,
                  'amount': price.amount,
                  if (price.isDefault) 'isDefault': true,
                },
              ),
            ),
          );
        }
        if (draft.prices.any((price) => price.isDefault) &&
            products.has('pim.product.update') &&
            (axes.isEmpty || generate)) {
          steps.add(
            PimGroupStep(
              draftId: draft.id,
              command: PimCommand(
                resource: PimResource.products,
                operation: 'update',
                id: item.id,
                body: {'status': 'ACTIVE', 'expectedRevision': item.revision},
              ),
            ),
          );
        }
      }
      state = PimGroupState(
        drafts: state.drafts,
        steps: steps,
        next: state.next + 1,
      );
      await store.write(key, state);
    }
    final submitted = state.steps.map((step) => step.draftId).toSet();
    await store.write(
      key,
      PimGroupState(
        drafts: state.drafts
            .where((draft) => !submitted.contains(draft.id))
            .toList(),
      ),
    );
  }
}
