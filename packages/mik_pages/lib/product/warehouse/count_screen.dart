import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/fab.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/source/remote/models/stock.dart';
import 'package:mik_data/source/remote/models/stock_count.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/stock.dart';
import 'package:mik_data/utils/fx/stock_count.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

const _states = {'OPEN': 'باز', 'POSTED': 'ثبت نهایی', 'CANCELLED': 'لغوشده'};
typedef _SendCount = Future<bool> Function(StockCountCommand);

class WarehouseCountScreen extends StatefulWidget {
  final String appId;
  final BusinessWarehouse warehouse;
  const WarehouseCountScreen({
    required this.appId,
    required this.warehouse,
    super.key,
  });
  @override
  State<WarehouseCountScreen> createState() => _WarehouseCountScreenState();
}

class _WarehouseCountScreenController extends GetxController {
  StockCountFX? fx;
  List<StockCount> rows = [];
  bool loading = true, saving = false;
  String? error;
  final filter = 'همه'.obs;
}

class _WarehouseCountScreenState extends State<WarehouseCountScreen> {
  late final _page = _WarehouseCountScreenController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  void fail(Object failure) {
    _page.error = StockCountFX.message(failure);
    Alert.error(_page.error!, context: context);
  }

  Future<Object> load() async {
    if (_page.saving) return '';
    {
      _page.loading = true;
      _page.error = null;
      _page.rows = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= StockCountFX(StockFX(active, widget.warehouse.warehouseId));
      await _page.fx!.restore();
      final result = await _page.fx!.all();
      if (mounted) {
        _page.rows = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  Future<Map<String, String>> names(List<Map<String, dynamic>> items) async {
    final pim = PimFX.forContext(_page.fx!.stock.context),
        result = <String, String>{},
        products = <String, String>{};
    try {
      await pim.authorize();
      if (!pim.has('pim.product.read') || !pim.has('pim.variant.read')) {
        return result;
      }
      for (final line in items) {
        final row = RemoteJson(line),
            id = row.text('variantId'),
            productId = row.text('productId');
        products[productId] ??=
            (await pim.get(PimResource.products, productId) as PimProduct).name;
        final variant = await pim.get(PimResource.variants, id) as PimVariant;
        if (variant.productId != productId) {
          throw const FormatException('Unexpected count product');
        }
        result[id] = '${products[productId]} — ${variant.name}';
      }
    } catch (failure) {
      // A missing display name must not prevent cancelling a locked count.
      if (mounted) {
        Alert.error(
          'نام بعضی اقلام دریافت نشد؛ با شناسه نمایش داده می‌شوند. ${PimFX.message(failure)}',
          context: context,
        );
      }
    }
    return result;
  }

  Future<bool> send(StockCountCommand command) async {
    if (_page.saving) return false;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (!mounted) return false;
      Alert.success(
        const {
          'start': 'شمارش آغاز شد؛ انبار تا ثبت نهایی یا لغو شمارش قفل است.',
          'update': 'مقادیر شمارش ذخیره شد؛ موجودی هنوز اصلاح نشده است.',
          'post': 'انبارگردانی ثبت نهایی شد؛ موجودی اصلاح و قفل انبار آزاد شد.',
          'cancel': 'شمارش لغو و قفل انبار آزاد شد.',
        }[command.action]!,
      );
      return true;
    } catch (failure) {
      if (mounted) fail(failure);
      return false;
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  Future<void> start() async {
    if (_page.loading || _page.saving || _page.fx?.pending != null) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      final stock = await _page.fx!.stock.balances();
      if (stock.blocked) {
        throw const AuthError(409, 'WAREHOUSE_COUNT_IN_PROGRESS');
      }
      final labels = await names(stock.items.map((r) => r.json).toList());
      _page.fx!.stock.check();
      if (!mounted) return;
      await Get.toNamed(
        nav_routes.RoutesName.COUNT_START,
        arguments: {
          'fx': _page.fx!,
          'items': stock.items,
          'labels': labels,
          'send': send,
        },
        preventDuplicates: false,
      );
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        {
          _page.loading = false;
          _page.update();
        }
        await load();
      }
    }
  }

  Future<void> open(StockCount item) async {
    if (_page.loading || _page.saving || _page.fx?.pending != null) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      final row = await _page.fx!.get(item.id),
          labels = await names(item.lines.map((r) => r.json).toList());
      _page.fx!.stock.check();
      if (!mounted) return;
      await Get.toNamed(
        nav_routes.RoutesName.COUNT_EDIT,
        arguments: {
          'row': row,
          'labels': labels,
          'fx': _page.fx!,
          'send': send,
        },
        preventDuplicates: false,
      );
    } catch (failure) {
      if (mounted) fail(failure);
    } finally {
      if (mounted) {
        {
          _page.loading = false;
          _page.update();
        }
        await load();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_WarehouseCountScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: 'انبارگردانی ${widget.warehouse.name}',
        ),
        floatingActionButton:
            _page.fx != null &&
                !_page.loading &&
                !_page.saving &&
                _page.error == null &&
                _page.fx!.pending == null &&
                !_page.rows.any((r) => r.status == 'OPEN')
            ? MyFAB(
                text: 'شمارش جدید',
                icon: IconsaxPlusLinear.add,
                onTap: start,
              )
            : const SizedBox.shrink(),
        child: (_) => Column(
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'دریافت مجدد شمارش‌ها',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.rows.any((r) => r.status == 'OPEN'))
              const Text('شمارش باز دارید؛ انبار تا ثبت نهایی یا لغو قفل است.'),
            if (_page.fx?.pending != null) ...[
              Text(
                'درخواست تعیین‌تکلیف‌نشده: ${const {'start': 'شروع شمارش', 'update': 'ذخیره مقادیر', 'post': 'ثبت نهایی', 'cancel': 'لغو'}[_page.fx!.pending!.action]}',
              ),
              BTN(
                name: 'پیگیری درخواست انبارگردانی',
                disabled: _page.loading || _page.saving,
                onTap: () async {
                  if (await send(_page.fx!.pending!) && mounted) await load();
                },
              ),
            ],
            MyTab(
              tab: const ['همه', 'باز', 'ثبت نهایی', 'لغوشده'],
              value: _page.filter,
              callback: (String v) {
                _page.filter.value = v;
                {
                  _page.update();
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 75),
                children: [
                  if (!_page.loading &&
                      _page.rows.isEmpty &&
                      _page.error == null)
                    const Text('شمارشی برای این انبار و شعبه ثبت نشده است.'),
                  for (final row in _page.rows.where(
                    (r) =>
                        _page.filter.value == 'همه' ||
                        _states[r.status] == _page.filter.value,
                  )) ...[
                    ListTile(
                      key: ValueKey('count-${row.id}'),
                      title: Text(row.json['reason'] as String),
                      subtitle: Text(
                        '${_states[row.status]} — ${DateConvertor.grigoriToJalali(DateTime.parse(row.json['createdAt'] as String))}\nاقلام: ${row.lines.length} | شمارش‌شده: ${row.lines.where((l) => l.counted).length}',
                      ),
                      onTap:
                          _page.loading ||
                              _page.saving ||
                              _page.fx?.pending != null
                          ? null
                          : () => open(row),
                    ),
                    MyDivider(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CountStartScreen extends StatefulWidget {
  final StockCountFX fx;
  final List<StockBalance> items;
  final Map<String, String> labels;
  final _SendCount send;
  const _CountStartScreen({
    required this.fx,
    required this.items,
    required this.labels,
    required this.send,
  });
  @override
  State<_CountStartScreen> createState() => _CountStartScreenState();
}

class _CountStartScreenController extends GetxController {
  final selected = <String>{};
  final reason = TextEditingController();
  final confirmed = 'خیر'.obs;
  bool saving = false;
}

class _CountStartScreenState extends State<_CountStartScreen> {
  late final _page = _CountStartScreenController();

  @override
  void dispose() {
    _page.reason.dispose();
    super.dispose();
  }

  Future<void> start() async {
    if (_page.saving) return;
    if (_page.selected.isEmpty ||
        _page.selected.length > 30 ||
        _page.reason.text.trim().isEmpty ||
        _page.reason.text.trim().length > 500 ||
        _page.confirmed.value != 'بله') {
      Alert.error(
        '۱ تا ۳۰ تنوع، دلیل و تأیید قفل کل انبار را مشخص کنید.',
        context: context,
      );
      return;
    }
    {
      _page.saving = true;
      _page.update();
    }
    try {
      final saved = await widget.send(
        StockCountCommand('start', {
          'warehouseId': widget.fx.stock.warehouseId,
          'variantIds': _page.selected.toList(),
          'reason': _page.reason.text.trim(),
        }),
      );
      if (mounted && (saved || widget.fx.pending != null)) {
        Get.back();
      }
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_CountStartScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'شمارش جدید'),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            const Text(
              'اقلام مورد شمارش را انتخاب کنید (حداکثر ۳۰ تنوع). شروع شمارش، جابه‌جایی کالا در کل انبار را تا ثبت نهایی یا لغو قفل می‌کند.',
            ),
            if (widget.items.isEmpty)
              const Text(
                'رکورد موجودی برای انتخاب وجود ندارد؛ ثبت موجودی اولیه در این مرحله انجام نمی‌شود.',
              ),
            for (final row in widget.items)
              MiniBTN(
                key: ValueKey('count-select-${row.variantId}'),
                name:
                    '${_page.selected.contains(row.variantId) ? '✓ ' : ''}${widget.labels[row.variantId] ?? row.variantId}',
                icon: IconsaxPlusLinear.box,
                noFlex: true,
                onTap: _page.saving
                    ? null
                    : () {
                        if (!_page.selected.remove(row.variantId)) {
                          _page.selected.add(row.variantId);
                        }
                        _page.confirmed.value = 'خیر';
                        _page.update();
                      },
              ),
            Input(
              key: const ValueKey('count-start-reason'),
              controller: _page.reason,
              name: 'دلیل شمارش',
              require: true,
              maxLength: 500,
              readOnly: _page.saving,
            ),
            const Text('شروع شمارش و قفل کل انبار را تأیید می‌کنید؟'),
            MyTab(
              tab: const ['خیر', 'بله'],
              value: _page.confirmed,
              enabledValues: _page.saving ? <String>{} : null,
              callback: (String v) => _page.confirmed.value = v,
            ),
            BTN(name: 'شروع شمارش', disabled: _page.saving, onTap: start),
          ],
        ),
      ),
    ),
  );
}

class _CountEditScreen extends StatefulWidget {
  final StockCountFX fx;
  final StockCount row;
  final Map<String, String> labels;
  final _SendCount send;
  const _CountEditScreen({
    required this.fx,
    required this.row,
    required this.labels,
    required this.send,
  });
  @override
  State<_CountEditScreen> createState() => _CountEditScreenState();
}

class _CountEditScreenController extends GetxController {
  final physical = <String, TextEditingController>{},
      damaged = <String, TextEditingController>{};
  final confirmed = 'خیر'.obs;
  bool saving = false, dirty = false;
}

class _CountEditScreenState extends State<_CountEditScreen> {
  late final _page = _CountEditScreenController();

  bool get editable => widget.row.status == 'OPEN';
  @override
  void initState() {
    super.initState();
    for (final row in widget.row.lines) {
      _page.physical[row.id] = TextEditingController(
        text: row.json['countedOnHand'] as String?,
      );
      _page.damaged[row.id] = TextEditingController(
        text: row.json['countedDamaged'] as String?,
      );
    }
  }

  @override
  void dispose() {
    for (final c in [..._page.physical.values, ..._page.damaged.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String normalize(String text) => InventoryQuantity.fromJson(
    text.trim().toEnglishDigit().replaceAll('٫', '.'),
  ).toString();
  String difference(StockCountLine line, String value, String key) {
    try {
      return line.difference(normalize(value), key);
    } catch (_) {
      return 'هنوز معتبر وارد نشده';
    }
  }

  Future<void> run(String action) async {
    if (_page.saving || !editable) return;
    try {
      final body = <String, dynamic>{
        'countId': widget.row.id,
        'expectedRevision': widget.row.revision,
      };
      if (action == 'update') {
        final lines = <Map<String, dynamic>>[];
        for (final row in widget.row.lines) {
          final a = _page.physical[row.id]!.text.trim(),
              b = _page.damaged[row.id]!.text.trim();
          if (a.isEmpty && b.isEmpty && !row.counted) continue;
          final onHand = normalize(a), bad = normalize(b);
          if (StockBalance.units(bad) > StockBalance.units(onHand)) {
            throw const FormatException('Damaged exceeds physical');
          }
          lines.add({
            'variantId': row.id,
            'countedOnHand': onHand,
            'countedDamaged': bad,
          });
        }
        if (lines.isEmpty) throw const FormatException('No explicit counts');
        body['lines'] = lines;
      } else if (action == 'post') {
        if (_page.dirty || widget.row.lines.any((l) => !l.counted)) {
          Alert.error(
            'همه اقلام را صریح شمارش و ذخیره کنید؛ صفر را هم وارد کنید.',
            context: context,
          );
          return;
        }
        if (_page.confirmed.value != 'بله') {
          Alert.error(
            'تأیید شمارش واقعی و اصلاح موجودی لازم است.',
            context: context,
          );
          return;
        }
      }
      {
        _page.saving = true;
        _page.update();
      }
      final saved = await widget.send(
        StockCountCommand(action, body, before: widget.row),
      );
      if (mounted && (saved || widget.fx.pending != null)) {
        Get.back();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is FormatException
              ? 'تعداد فیزیکی و آسیب‌دیده را صریح با حداکثر ۶ رقم اعشار وارد کنید؛ آسیب‌دیده نمی‌تواند از فیزیکی بیشتر باشد.'
              : StockCountFX.message(failure),
          context: context,
        );
      }
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<_CountEditScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'جزئیات شمارش'),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            Text('وضعیت: ${_states[widget.row.status]}'),
            Text(widget.row.json['reason'] as String),
            if (editable)
              const Text(
                'انبار قفل است. تعداد فیزیکی شامل آسیب‌دیده است؛ تعداد آسیب‌دیده بخشی از همان تعداد است. فیلد خالی به معنی صفر نیست. ذخیره مقادیر، موجودی را اصلاح نمی‌کند؛ ثبت نهایی لازم است.',
              ),
            if (_page.saving) const LinearProgressIndicator(),
            for (final row in widget.row.lines) ...[
              MyDivider(text: widget.labels[row.id] ?? 'شناسه تنوع: ${row.id}'),
              Text(
                'مبنای فیزیکی: ${row.amount('onHand')} | آسیب‌دیده: ${row.amount('damaged')}',
              ),
              Text(
                'رزرو: ${row.amount('reserved')} | در انتظار تخصیص: ${row.amount('allocationPending')}',
              ),
              Input(
                key: ValueKey('count-physical-${row.id}'),
                controller: _page.physical[row.id]!,
                name: 'تعداد فیزیکی شمارش‌شده (شامل آسیب‌دیده)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: _page.saving || !editable,
                onChanged: (_) {
                  _page.dirty = true;
                  _page.confirmed.value = 'خیر';
                  _page.update();
                },
              ),
              Input(
                key: ValueKey('count-damaged-${row.id}'),
                controller: _page.damaged[row.id]!,
                name: 'تعداد آسیب‌دیده شمارش‌شده',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: _page.saving || !editable,
                onChanged: (_) {
                  _page.dirty = true;
                  _page.confirmed.value = 'خیر';
                  _page.update();
                },
              ),
              Text(
                'اختلاف فیزیکی: ${difference(row, _page.physical[row.id]!.text, 'onHand')}',
              ),
              Text(
                'اختلاف آسیب‌دیده: ${difference(row, _page.damaged[row.id]!.text, 'damaged')}',
              ),
            ],
            if (editable) ...[
              BTN(
                name: 'ذخیره مقادیر شمارش',
                disabled: _page.saving,
                onTap: () => run('update'),
              ),
              const Text(
                'تأیید می‌کنید مقادیر ذخیره‌شده، نتیجه شمارش واقعی است و اختلاف آن‌ها در موجودی ثبت شود؟',
              ),
              MyTab(
                tab: const ['خیر', 'بله'],
                value: _page.confirmed,
                enabledValues: _page.saving ? <String>{} : null,
                callback: (String v) => _page.confirmed.value = v,
              ),
              BTN(
                name: 'ثبت نهایی انبارگردانی',
                disabled: _page.saving,
                onTap: () => run('post'),
              ),
              BTN(
                name: 'لغو شمارش',
                type: BTNType.cancel,
                disabled: _page.saving,
                onTap: () => Confirm.con(
                  context,
                  type: ConfirmType.DELETE,
                  confirmText: 'لغو شمارش',
                  subtext: 'شمارش بدون اصلاح موجودی لغو و قفل انبار آزاد شود؟',
                  onTapConfirm: () async {
                    Get.back();
                    await run('cancel');
                  },
                ),
              ),
              MiniBTN(
                name: 'دریافت نسخه جدید شمارش',
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                onTap: _page.saving ? null : () => Get.back(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildCountStartRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _CountStartScreen(
    fx: args.required<StockCountFX>('fx'),
    items: args.required<List<StockBalance>>('items'),
    labels: args.required<Map<String, String>>('labels'),
    send: args.required<Future<bool> Function(StockCountCommand)>('send'),
  );
}

Widget buildCountEditRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _CountEditScreen(
    fx: args.required<StockCountFX>('fx'),
    row: args.required<StockCount>('row'),
    labels: args.required<Map<String, String>>('labels'),
    send: args.required<Future<bool> Function(StockCountCommand)>('send'),
  );
}

Widget buildWarehouseCountRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return WarehouseCountScreen(
    appId: args.required<String>('appId'),
    warehouse: args.required<BusinessWarehouse>('warehouse'),
  );
}
