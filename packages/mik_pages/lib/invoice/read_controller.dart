import 'package:mik_data/utils/fx/realtime.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/invoice_read.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/invoice_read.dart';

class InvoiceReadController extends GetxController {
  final String appId;
  final void Function(String message, bool success)? onNotice;
  InvoiceReadController({required this.appId, this.onNotice});
  final type = 'SALE'.obs;
  final status = RxnString(), error = RxnString(), next = RxnString();
  final loading = false.obs;
  final rows = <RemoteInvoiceSummary>[].obs;
  final _cursors = <String>{}, _ids = <String>{};
  InvoiceReadFX? fx;
  RealtimeWatch? _realtime;
  int _generation = 0;
  bool _closed = false;
  void fail(Object failure) {
    if (_closed) return;
    error.value = InvoiceReadFX.message(failure);
    if (failure is AuthError &&
        (failure.statusCode == 403 ||
            failure.requiresLogin ||
            failure.code == 'SELECTION_CHANGED')) {
      rows.clear();
      next.value = null;
    }
    onNotice?.call(error.value!, false);
  }

  Future<void> load({bool more = false}) async {
    if (_closed || more && (loading.value || next.value == null)) return;
    final generation = ++_generation, requested = type.value;
    final filter = status.value, cursor = more ? next.value : null;
    loading.value = true;
    error.value = null;
    if (!more) {
      rows.clear();
      next.value = null;
      _cursors.clear();
      _ids.clear();
    }
    try {
      final context = BusinessContext.forApp(appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      fx ??= InvoiceReadFX(context);
      _realtime ??= RealtimeWatch(
        RealtimeFX.forContext(context),
        {
          'accounting.sale',
          'accounting.purchase',
          'accounting.proforma',
          'accounting.payment',
          'accounting.cheque',
          'accounting.event',
          'accounting.operation',
        },
        refreshFromServer,
        invalidate: () {
          _generation++;
          rows.clear();
          next.value = null;
        },
      );
      await fx!.authorize(requested);
      final page = await fx!.page(requested, after: cursor, status: filter);
      if (_closed || generation != _generation) return;
      final ids = page.items.map((r) => r.id).toList();
      if (ids.toSet().length != ids.length ||
          ids.any(_ids.contains) ||
          page.next != null &&
              (!Uuid.isValidUUID(fromString: page.next!) ||
                  _cursors.contains(page.next))) {
        throw const FormatException('Repeated invoice page');
      }
      _ids.addAll(ids);
      if (page.next != null) _cursors.add(page.next!);
      rows.assignAll(
        [...rows, ...page.items]
          ..sort(RemoteInvoiceSummary.compareNumberDescending),
      );
      next.value = page.next;
    } catch (failure) {
      if (generation == _generation) fail(failure);
    } finally {
      if (!_closed && generation == _generation) loading.value = false;
    }
  }

  Future<void> refreshFromServer() async {
    if (_closed) return;
    final generation = ++_generation, requested = type.value;
    final filter = status.value, count = rows.length;
    final refreshed = <RemoteInvoiceSummary>[];
    final ids = <String>{}, cursors = <String>{};
    String? cursor;
    try {
      final client = fx;
      if (client == null) return;
      await client.authorize(requested);
      do {
        final page = await client.page(
          requested,
          after: cursor,
          status: filter,
        );
        if (_closed || generation != _generation) return;
        for (final row in page.items) {
          if (!ids.add(row.id)) {
            throw const FormatException('Repeated invoice page');
          }
        }
        if (page.next != null &&
            (!Uuid.isValidUUID(fromString: page.next!) ||
                !cursors.add(page.next!))) {
          throw const FormatException('Repeated invoice page');
        }
        refreshed.addAll(page.items);
        cursor = page.next;
      } while (refreshed.length < count && cursor != null);
      // Publish the complete replacement together; keep the current rows during the read.
      refreshed.sort(RemoteInvoiceSummary.compareNumberDescending);
      rows.assignAll(refreshed);
      next.value = cursor;
      _ids
        ..clear()
        ..addAll(ids);
      _cursors
        ..clear()
        ..addAll(cursors);
      error.value = null;
    } catch (failure) {
      if (generation == _generation) fail(failure);
    } finally {
      if (!_closed && generation == _generation) loading.value = false;
    }
  }

  void selectType(String value) {
    type.value = value;
    status.value = null;
    load();
  }

  Future<RemoteInvoiceDetail?> detail(String id, String documentType) async {
    try {
      final client = fx;
      if (client == null) throw const AuthError(401, 'SESSION_INVALID');
      final result = await client.detail(id, documentType);
      if (_closed) return null;
      return result;
    } catch (failure) {
      fail(failure);
      return null;
    }
  }

  @override
  void onClose() {
    _realtime?.dispose();
    _closed = true;
    _generation++;
    super.onClose();
  }
}
