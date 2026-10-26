import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_components/elements/input/searchbar.dart';
import 'package:mik_components/elements/myTab.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/source/remote/models/stock.dart';
import 'package:mik_data/source/remote/models/inventory_quantity.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/stock.dart';
import 'package:mik_utils/public/date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

const _buckets = {
  'onHand': 'فیزیکی',
  'available': 'قابل فروش',
  'reserved': 'رزرو',
  'damaged': 'آسیب‌دیده',
  'allocationPending': 'در انتظار تخصیص',
};
const _reasons = {
  'COUNT_CORRECTION': 'اصلاح انبارگردانی',
  'SALE': 'خروج فروش',
  'PURCHASE': 'ورود خرید',
  'RESERVATION_RELEASE': 'آزادسازی رزرو',
  'RESERVATION_EXPIRED': 'انقضای رزرو',
  'ADJUSTMENT_IN': 'اصلاح افزایشی',
  'ADJUSTMENT_OUT': 'اصلاح کاهشی',
  'TRANSFER_IN': 'ورود از انتقال',
  'TRANSFER_OUT': 'خروج برای انتقال',
  'QUARANTINE': 'آسیب‌دیده',
  'RESTORE': 'بازگشت به سالم',
  'SCRAP': 'اسقاط',
};

class WarehouseStockScreen extends StatefulWidget {
  final String appId;
  final BusinessWarehouse warehouse;
  final bool transfer, kardex;
  final String? productId, productName;
  const WarehouseStockScreen({
    required this.appId,
    required this.warehouse,
    this.transfer = false,
    this.kardex = false,
    this.productId,
    this.productName,
    super.key,
  });
  @override
  State<WarehouseStockScreen> createState() => _WarehouseStockScreenState();
}

class _WarehouseStockScreenController extends GetxController {
  RealtimeWatch? _realtime;
  int _readGeneration = 0;
  StockFX? fx;
  List<StockBalance> rows = [];
  final labels = <String, String>{}, grants = <String, bool>{};
  final search = TextEditingController();
  String query = '';
  bool loading = true, saving = false, blocked = false, opening = false;
  String? error;
}

class _WarehouseStockScreenState extends State<WarehouseStockScreen> {
  late final _page = _WarehouseStockScreenController();

  @override
  void initState() {
    super.initState();
    final realtimeContext = BusinessContext.forApp(widget.appId);
    if (realtimeContext != null) {
      _page._realtime = RealtimeWatch(
        RealtimeFX.forContext(realtimeContext),
        {
          'inventory.balance',
          'inventory.reservation',
          'inventory.movement',
          'inventory.count',
          'inventory.transfer',
          'inventory.commitment',
          'pim.product',
          'pim.variant',
        },
        () async {
          await load(background: true);
        },
        busy: () => _page.loading || _page.saving || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page._readGeneration++;
              _page.loading = false;
              _page.rows = [];
              _page.labels.clear();
              _page.grants.clear();
              _page.update();
            }
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page._realtime?.dispose();
    _page._readGeneration++;
    _page.search.dispose();
    super.dispose();
  }

  void fail(Object failure) {
    _page.error = StockFX.message(failure);
    Alert.error(_page.error!, context: context);
  }

  Future<Object> load({bool background = false}) async {
    if (!mounted || _page.saving) return '';
    final request = ++_page._readGeneration;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.rows = [];
      if (!background) _page.grants.clear();
      if (!background) _page.labels.clear();
      _page.update();
    }
    try {
      final context = BusinessContext.forApp(widget.appId);
      if (context == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= StockFX(context, widget.warehouse.warehouseId);
      await _page.fx!.restore();
      final result = await _page.fx!.balances();
      if (!mounted || request != _page._readGeneration) return '';
      final loadedGrants = <String, bool>{}, loadedLabels = <String, String>{};
      for (final operation in [
        'READ_KARDEX',
        'TRANSFER_OUT',
        'ADJUST_STOCK',
        'MANAGE_CONDITION',
        'RECEIVE_STOCK',
        'ISSUE_STOCK',
      ]) {
        loadedGrants[operation] = await _page.fx!.allowed(operation);
      }
      if (!mounted || request != _page._readGeneration) return '';
      {
        _page.rows = result.items
            .where(
              (row) =>
                  widget.productId == null || row.productId == widget.productId,
            )
            .toList();
        _page.blocked = result.blocked;
        _page.update();
      }
      // Names need PIM read grants; stock remains readable without those grants.
      final pim = PimFX.forContext(context);
      await pim.authorize();
      if (pim.has('pim.product.read') && pim.has('pim.variant.read')) {
        final products = <String, String>{};
        for (final row in _page.rows) {
          products[row.productId] ??= (await pim.get(
            PimResource.products,
            row.productId,
          ) as PimProduct).name;
          final variant =
              await pim.get(PimResource.variants, row.variantId) as PimVariant;
          if (variant.productId != row.productId) {
            throw const FormatException('Unexpected stock variant');
          }
          loadedLabels[row.variantId] =
              '${products[row.productId]} — ${variant.name}';
        }
      }
      _page.fx!.check();
      if (mounted && request == _page._readGeneration) {
        _page.grants.addAll(loadedGrants);
        _page.labels.addAll(loadedLabels);
      }
    } catch (failure) {
      if (mounted && request == _page._readGeneration) fail(failure);
    } finally {
      if (mounted && request == _page._readGeneration) {
        {
          _page.loading = false;
          _page.update();
        }
      }
    }
    return '';
  }

  Future<bool> send(StockCommand command) async {
    if (_page.saving) return false;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      await _page.fx!.send(command);
      if (!mounted) return false;
      Alert.success('عملیات انبار با موفقیت ثبت شد.');
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

  Future<void> open(StockBalance row) async {
    if (_page.loading || _page.saving || _page.fx!.pending != null) return;
    if (widget.kardex && _page.grants['READ_KARDEX'] != true ||
        widget.transfer &&
            (_page.blocked || _page.grants['TRANSFER_OUT'] != true)) {
      Alert.error(
        _page.blocked && widget.transfer
            ? 'انبار برای انبارگردانی قفل است؛ انتقال امکان‌پذیر نیست.'
            : 'اجازه انجام این عملیات را ندارید.',
        context: context,
      );
      return;
    }
    _page.opening = true;
    try {
      await Get.toNamed(
        nav_routes.RoutesName.STOCK_ITEM,
        arguments: {
          'fx': _page.fx!,
          'row': row,
          'name': _page.labels[row.variantId] ?? 'شناسه تنوع: ${row.variantId}',
          'grants': Map.of(_page.grants),
          'blocked': _page.blocked,
          'transfer': widget.transfer,
          'send': send,
        },
        preventDuplicates: false,
      );
    } finally {
      _page.opening = false;
    }
    if (mounted) await load();
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_WarehouseStockScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(
          context,
          text: widget.productId == null
              ? 'موجودی ${widget.warehouse.name}'
              : '${widget.transfer ? 'انتقال' : 'کاردکس'} ${widget.productName ?? 'کالا'}',
        ),
        child: (_) => Column(
          children: [
            MySearchBar(
              controller: _page.search,
              type: SearchBarType.product,
              enableScanner: false,
              callback: (v) {
                _page.query = v.toString().trim();
                _page.update();
              },
            ),
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.error != null)
              Text(_page.error!, textAlign: TextAlign.center),
            MiniBTN(
              name: 'دریافت مجدد موجودی',
              noFlex: true,
              icon: IconsaxPlusLinear.refresh,
              onTap: _page.loading || _page.saving ? null : load,
            ),
            if (_page.blocked)
              const Text(
                'انبار برای انبارگردانی قفل است؛ عملیات تغییر موجودی غیرفعال است.',
              ),
            if (_page.fx?.pending != null) ...[
              const Text(
                'نتیجه درخواست قبلی مشخص نیست؛ درخواست تازه ثبت نکنید.',
              ),
              Text(
                'نوع عملیات: ${const {'transfer': 'انتقال', 'adjust': 'اصلاح موجودی', 'condition': 'تغییر وضعیت کالا'}[_page.fx!.pending!.action]} — تعداد: ${_page.fx!.pending!.body['quantity']}',
              ),
              BTN(
                name: 'پیگیری عملیات انبار',
                disabled: _page.loading || _page.saving,
                onTap: () async {
                  if (await send(_page.fx!.pending!) && mounted) await load();
                },
              ),
            ],
            Expanded(
              child: ListView(
                children: [
                  if (!_page.loading &&
                      _page.rows.isEmpty &&
                      _page.error == null)
                    const Center(
                      child: Text('رکورد موجودی برای این انبار وجود ندارد.'),
                    ),
                  for (final row in _page.rows.where(
                    (r) =>
                        _page.query.isEmpty ||
                        (_page.labels[r.variantId] ?? r.variantId).contains(
                          _page.query,
                        ),
                  ))
                    Column(
                      children: [
                        ListTile(
                          key: ValueKey('stock-${row.id}'),
                          title: Text(
                            _page.labels[row.variantId] ??
                                'شناسه تنوع: ${row.variantId}',
                          ),
                          subtitle: Text(
                            'فیزیکی: ${row.quantity('onHand')} | قابل فروش: ${row.quantity('available')}\nرزرو: ${row.quantity('reserved')} | آسیب‌دیده: ${row.quantity('damaged')} | در انتظار تخصیص: ${row.quantity('allocationPending')}',
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
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StockItemScreen extends StatefulWidget {
  final StockFX fx;
  final StockBalance row;
  final String name;
  final Map<String, bool> grants;
  final bool blocked, transfer;
  final Future<bool> Function(StockCommand) send;
  const _StockItemScreen({
    required this.fx,
    required this.row,
    required this.name,
    required this.grants,
    required this.blocked,
    required this.transfer,
    required this.send,
  });
  @override
  State<_StockItemScreen> createState() => _StockItemScreenState();
}

class _StockItemScreenController extends GetxController {
  final mode = 'گردش کالا'.obs,
      condition = 'سالم'.obs,
      direction = 'افزایش'.obs,
      action = 'آسیب‌دیده'.obs,
      confirmed = 'خیر'.obs;
  final quantity = TextEditingController(), reason = TextEditingController();
  List<BusinessBranch> branches = [];
  List<BusinessWarehouse> destinations = [];
  BusinessWarehouse? destination;
  String? branch;
  bool loading = false, saving = false;
  List<StockMovement>? movements;
  String? closing;
}

class _StockItemScreenState extends State<_StockItemScreen> {
  late final _page = _StockItemScreenController();

  List<String> get modes => [
    if (widget.grants['READ_KARDEX'] == true) 'گردش کالا',
    if (!widget.blocked) ...[
      if (widget.grants['TRANSFER_OUT'] == true) 'انتقال',
      if (widget.grants['ADJUST_STOCK'] == true &&
          (widget.grants['RECEIVE_STOCK'] == true ||
              widget.grants['ISSUE_STOCK'] == true))
        'اصلاح موجودی',
      if (widget.grants['MANAGE_CONDITION'] == true) 'وضعیت کالا',
    ],
  ];
  @override
  void initState() {
    super.initState();
    if (modes.isNotEmpty) {
      _page.mode.value = widget.transfer && modes.contains('انتقال')
          ? 'انتقال'
          : modes.first;
    }
    if (widget.grants['RECEIVE_STOCK'] != true) _page.direction.value = 'کاهش';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) prepare();
    });
  }

  @override
  void dispose() {
    _page.quantity.dispose();
    _page.reason.dispose();
    super.dispose();
  }

  Future<void> prepare() async {
    if (_page.loading || _page.saving || modes.isEmpty) return;
    {
      _page.loading = true;
      _page.update();
    }
    try {
      widget.fx.check();
      if (_page.mode.value == 'گردش کالا') {
        _page.movements = null;
        _page.closing = null;
        final result = await widget.fx.kardex(widget.row);
        _page.movements = result.items;
        _page.closing = RemoteJson(result.closing).text('onHand');
      } else if (_page.mode.value == 'انتقال') {
        _page.destinations = [];
        _page.destination = null;
        _page.branches = await widget.fx.branches();
        _page.branch ??= widget.fx.branchId;
        _page.destinations = await widget.fx.destinations(_page.branch!);
        _page.destination = null;
        if (_page.destinations.isEmpty && mounted) {
          Alert.error(
            'انبار مقصد مجاز در این شعبه وجود ندارد.',
            context: context,
          );
        }
      }
    } catch (failure) {
      if (mounted) Alert.error(StockFX.message(failure), context: context);
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> submit() async {
    if (_page.saving || _page.loading || _page.mode.value == 'گردش کالا')
      return;
    try {
      final value = InventoryQuantity.fromJson(
        _page.quantity.text.trim().toEnglishDigit().replaceAll('٫', '.'),
      );
      if (value.isZero ||
          _page.reason.text.trim().isEmpty ||
          _page.reason.text.trim().length > 500 ||
          _page.confirmed.value != 'بله') {
        throw const FormatException('Confirm real stock movement');
      }
      final body = <String, dynamic>{
        'variantId': widget.row.variantId,
        'quantity': value.toString(),
        'reason': _page.reason.text.trim(),
      };
      final String operation;
      if (_page.mode.value == 'انتقال') {
        if (_page.destination == null || _page.branch == null) {
          throw const FormatException('Select destination');
        }
        operation = 'transfer';
        body.addAll({
          'fromWarehouseId': widget.fx.warehouseId,
          'toWarehouseId': _page.destination!.warehouseId,
          'toBranchId': _page.branch,
          'condition': _page.condition.value == 'سالم' ? 'SELLABLE' : 'DAMAGED',
        });
      } else {
        body.addAll({
          'warehouseId': widget.fx.warehouseId,
          'expectedRevision': widget.row.revision,
        });
        operation = _page.mode.value == 'اصلاح موجودی' ? 'adjust' : 'condition';
        if (operation == 'adjust') {
          body['direction'] = _page.direction.value == 'افزایش' ? 'IN' : 'OUT';
        } else {
          body['action'] = const {
            'آسیب‌دیده': 'QUARANTINE',
            'بازگشت به سالم': 'RESTORE',
            'اسقاط': 'SCRAP',
          }[_page.action.value];
        }
      }
      {
        _page.saving = true;
        _page.update();
      }
      final saved = await widget.send(
        StockCommand(operation, body, widget.row),
      );
      if (mounted && (saved || widget.fx.pending != null)) {
        Get.back();
      }
    } catch (failure) {
      if (mounted) {
        Alert.error(
          failure is FormatException
              ? 'تعداد مثبت تا ۶ رقم اعشار، دلیل، مقصد و تأیید عملیات واقعی را بررسی کنید.'
              : StockFX.message(failure),
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
  Widget build(BuildContext context) => GetBuilder<_StockItemScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: widget.name),
        child: (_) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final entry in _buckets.entries)
              Text('${entry.value}: ${widget.row.quantity(entry.key)}'),
            MyDivider(text: 'عملیات کالا'),
            if (modes.isEmpty)
              const Text('مجوز عملیات یا مشاهده گردش این انبار را ندارید.'),
            if (modes.isNotEmpty)
              MyTab(
                tab: modes,
                value: _page.mode,
                enabledValues: _page.loading || _page.saving
                    ? <String>{}
                    : null,
                callback: (String v) {
                  _page.mode.value = v;
                  _page.confirmed.value = 'خیر';
                  {
                    _page.update();
                  }
                  prepare();
                },
              ),
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.mode.value == 'گردش کالا' &&
                modes.contains('گردش کالا')) ...[
              MiniBTN(
                name: 'دریافت مجدد گردش کالا',
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                onTap: _page.loading || _page.saving ? null : prepare,
              ),
              if (_page.closing != null)
                Text('موجودی فیزیکی پایان گزارش: ${_page.closing}'),
              if (_page.movements?.isEmpty == true)
                const Text('گردشی ثبت نشده است.'),
              for (final row in _page.movements ?? <StockMovement>[]) ...[
                MyDivider(
                  text:
                      _reasons[row.json['reason']] ??
                      row.json['reason'] as String,
                ),
                Text(
                  DateConvertor.grigoriToJalali(
                    DateTime.parse(row.json['createdAt'] as String),
                  ),
                ),
                Text(
                  'تغییر فیزیکی: ${row.delta} | مانده فیزیکی: ${RemoteJson(row.json['after']).text('onHand')}',
                ),
                Text(
                  'تغییر آسیب‌دیده: ${RemoteJson(row.json['before']).text('damaged')} ← ${RemoteJson(row.json['after']).text('damaged')}',
                ),
                if (RemoteJson(row.json['reference']).optionalText('reason') !=
                    null)
                  Text(RemoteJson(row.json['reference']).text('reason')),
                SelectableText(
                  'مرجع: ${RemoteJson(row.json['reference']).text('type')} — ${RemoteJson(row.json['reference']).text('id')}',
                ),
              ],
            ] else if (modes.contains(_page.mode.value)) ...[
              if (_page.mode.value == 'انتقال') ...[
                MyDivider(text: 'شعبه مقصد'),
                for (final row in _page.branches)
                  MiniBTN(
                    name:
                        '${_page.branch == row.branchId ? '✓ ' : ''}${row.name}',
                    noFlex: true,
                    icon: IconsaxPlusLinear.home,
                    onTap: _page.loading || _page.saving
                        ? null
                        : () {
                            _page.branch = row.branchId;
                            _page.confirmed.value = 'خیر';
                            prepare();
                          },
                  ),
                MyDivider(text: 'انبار مقصد'),
                for (final row in _page.destinations)
                  MiniBTN(
                    name:
                        '${_page.destination?.warehouseId == row.warehouseId ? '✓ ' : ''}${row.name}',
                    noFlex: true,
                    icon: IconsaxPlusLinear.box,
                    onTap: _page.loading || _page.saving
                        ? null
                        : () {
                            _page.destination = row;
                            _page.confirmed.value = 'خیر';
                            _page.update();
                          },
                  ),
                MiniBTN(
                  name: 'دریافت مجدد مقصدها',
                  noFlex: true,
                  icon: IconsaxPlusLinear.refresh,
                  onTap: _page.loading || _page.saving ? null : prepare,
                ),
                MyTab(
                  tab: const ['سالم', 'آسیب‌دیده'],
                  value: _page.condition,
                  enabledValues: _page.loading || _page.saving
                      ? <String>{}
                      : null,
                  callback: (String v) {
                    _page.condition.value = v;
                    _page.confirmed.value = 'خیر';
                  },
                ),
              ],
              if (_page.mode.value == 'اصلاح موجودی') ...[
                const Text(
                  'این عملیات اصلاح اختلاف موجودی است و جایگزین خرید، فروش یا ثبت موجودی اولیه نیست.',
                ),
                MyTab(
                  tab: [
                    if (widget.grants['RECEIVE_STOCK'] == true) 'افزایش',
                    if (widget.grants['ISSUE_STOCK'] == true) 'کاهش',
                  ],
                  value: _page.direction,
                  enabledValues: _page.loading || _page.saving
                      ? <String>{}
                      : null,
                  callback: (String v) {
                    _page.direction.value = v;
                    _page.confirmed.value = 'خیر';
                  },
                ),
              ],
              if (_page.mode.value == 'وضعیت کالا') ...[
                const Text(
                  'آسیب‌دیده: خروج از موجودی قابل فروش؛ بازگشت به سالم: رفع آسیب؛ اسقاط: خروج واقعی کالای آسیب‌دیده از انبار.',
                ),
                MyTab(
                  tab: const ['آسیب‌دیده', 'بازگشت به سالم', 'اسقاط'],
                  value: _page.action,
                  enabledValues: _page.loading || _page.saving
                      ? <String>{}
                      : null,
                  callback: (String v) {
                    _page.action.value = v;
                    _page.confirmed.value = 'خیر';
                  },
                ),
              ],
              Input(
                key: const ValueKey('stock-quantity'),
                controller: _page.quantity,
                name: 'تعداد',
                require: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                readOnly: _page.loading || _page.saving,
                onChanged: (_) => _page.confirmed.value = 'خیر',
              ),
              Input(
                key: const ValueKey('stock-reason'),
                controller: _page.reason,
                name: 'دلیل عملیات',
                require: true,
                maxLength: 500,
                readOnly: _page.loading || _page.saving,
              ),
              const Text(
                'تأیید می‌کنید تغییر یا جابه‌جایی واقعی کالا مطابق اطلاعات بالا انجام شده است؟',
              ),
              MyTab(
                tab: const ['خیر', 'بله'],
                value: _page.confirmed,
                enabledValues: _page.loading || _page.saving
                    ? <String>{}
                    : null,
                callback: (String v) => _page.confirmed.value = v,
              ),
              BTN(
                name: 'ثبت عملیات انبار',
                disabled: _page.loading || _page.saving,
                onTap: submit,
              ),
              MiniBTN(
                name: 'دریافت نسخه جدید موجودی',
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                onTap: _page.saving || _page.loading
                    ? null
                    : () => Get.back(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildWarehouseStockRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return WarehouseStockScreen(
    appId: args.required<String>('appId'),
    warehouse: args.required<BusinessWarehouse>('warehouse'),
    transfer: args.optional<bool>('transfer') ?? false,
    kardex: args.optional<bool>('kardex') ?? false,
    productId: args.optional<String>('productId'),
    productName: args.optional<String>('productName'),
  );
}

Widget buildStockItemRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return _StockItemScreen(
    fx: args.required<StockFX>('fx'),
    row: args.required<StockBalance>('row'),
    name: args.required<String>('name'),
    grants: args.required<Map<String, bool>>('grants'),
    blocked: args.required<bool>('blocked'),
    transfer: args.required<bool>('transfer'),
    send: args.required<Future<bool> Function(StockCommand)>('send'),
  );
}
