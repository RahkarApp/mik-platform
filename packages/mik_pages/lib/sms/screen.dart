import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/loader.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/confirm.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/input.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/business_sms.dart';
import 'package:mik_data/source/remote/models/remote_json.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/business_sms.dart';
import 'package:mik_data/utils/fx/realtime.dart';
import 'package:mik_utils/public/price.dart';

String smsEventName(String key) {
  const types = {
    'SALE': 'فروش',
    'PURCHASE': 'خرید',
    'PROFORMA': 'پیش‌فاکتور',
    'PRESALE': 'پیش‌فروش',
    'SALE_RETURN': 'برگشت فروش',
    'PURCHASE_RETURN': 'برگشت خرید',
  };
  const actions = {
    'ISSUED': 'ثبت',
    'READY': 'آماده‌سازی',
    'SHIPPED': 'ارسال',
    'DELIVERED': 'تحویل',
    'CANCELLED': 'لغو',
    'AMENDED': 'اصلاح',
    'EXPIRED': 'انقضا',
    'RETURNED': 'مرجوعی',
  };
  final split = key.lastIndexOf('_');
  if (split > 0 &&
      types.containsKey(key.substring(0, split)) &&
      actions.containsKey(key.substring(split + 1))) {
    return '${actions[key.substring(split + 1)]} ${types[key.substring(0, split)]}';
  }
  const club = {
    'CLUB_BIRTHDAY': 'تولد مشتری',
    'CLUB_ANNIVERSARY': 'سالگرد',
    'CLUB_POINTS_EARNED': 'کسب امتیاز',
    'CLUB_POINTS_EXPIRING': 'انقضای امتیاز',
    'CLUB_CASHBACK_EARNED': 'اعتبار خرید',
    'CLUB_CAMPAIGN': 'کمپین',
  };
  return club[key] ?? key;
}

const smsEntryReasons = {
  'PAYMENT_TOPUP': 'شارژ آنلاین',
  'WELCOME': 'اعتبار خوشامدگویی',
  'ADMIN_CREDIT': 'افزایش اعتبار',
  'SMS_SEND': 'هزینه ارسال پیامک',
  'TRANSFER_IN': 'دریافت اعتبار',
  'TRANSFER_OUT': 'انتقال اعتبار',
  'UNSENT_RELEASE': 'آزادسازی اعتبار پیامک ارسال‌نشده',
  'SALE_RECEIPT': 'دریافت فروش',
};

class BusinessSmsScreen extends StatefulWidget {
  final String appId, section;
  const BusinessSmsScreen({
    this.appId = 'mik',
    this.section = 'events',
    super.key,
  });
  @override
  State<BusinessSmsScreen> createState() => _BusinessSmsScreenState();
}

class _BusinessSmsScreenController extends GetxController {
  RealtimeWatch? realtime;
  BusinessSmsFX? fx;
  SmsWallet? wallet;
  Map<String, List<String>> events = {};
  List<SmsTemplate> templates = [];
  List<RemoteJson> rows = [];
  final cursors = <String>{};
  String? next, error;
  bool loading = true, moreLoading = false, opening = false;
  int generation = 0;
  late DateTime end = DateTime.now().toUtc();
  late DateTime start = end.subtract(const Duration(days: 7));
}

class _BusinessSmsScreenState extends State<BusinessSmsScreen> {
  late final _page = _BusinessSmsScreenController();

  String get title => switch (widget.section) {
    'history' => 'تاریخچه ارسال پیامک',
    'wallet' => 'اعتبار پیامک',
    _ => 'اطلاع‌رسانی هوشمند',
  };
  @override
  void initState() {
    super.initState();
    final context = BusinessContext.forApp(widget.appId);
    if (context != null) {
      _page.fx = BusinessSmsFX(context);
      _page.realtime = RealtimeWatch(
        RealtimeFX.forContext(context),
        {
          'wallet.account',
          'notification.template',
          'notification.template-default',
          'notification.message',
        },
        () => load(background: true),
        busy: () => _page.loading || _page.moreLoading || _page.opening,
        invalidate: () {
          if (mounted) {
            {
              _page.generation++;
              _page.loading = false;
              _page.wallet = null;
              _page.events = {};
              _page.templates = [];
              _page.rows = [];
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
    _page.realtime?.dispose();
    _page.generation++;
    super.dispose();
  }

  Future<void> load({bool background = false}) async {
    final request = ++_page.generation;
    {
      if (!background) _page.loading = true;
      _page.error = null;
      if (!background) _page.wallet = null;
      if (!background) _page.events = {};
      if (!background) _page.templates = [];
      if (!background) _page.rows = [];
      _page.next = null;
      _page.cursors.clear();
      _page.update();
    }
    try {
      if (_page.fx == null) throw const AuthError(401, 'SESSION_INVALID');
      await _page.fx!.authorize();
      await _page.fx!.restore();
      if (widget.section == 'events' || widget.section == 'wallet') {
        // Each panel has its own permission; a missing wallet grant must not hide templates.
        if (_page.fx!.has('balance.read')) {
          try {
            final result = await _page.fx!.wallet();
            if (mounted && request == _page.generation) {
              {
                _page.wallet = result;
                _page.update();
              }
            }
          } catch (e) {
            if (mounted && request == _page.generation) {
              Alert.error(BusinessSmsFX.messageFor(e));
            }
          }
        }
      }
      if (widget.section == 'events') {
        if (!_page.fx!.has('template.read'))
          throw const AuthError(403, 'FORBIDDEN');
        final catalog = await _page.fx!.events(),
            items = await _page.fx!.templates();
        if (mounted && request == _page.generation) {
          {
            _page.events = catalog;
            _page.templates = items;
            _page.update();
          }
        }
      } else {
        if (widget.section == 'history') {
          _page.end = DateTime.now().toUtc();
          _page.start = _page.end.subtract(const Duration(days: 7));
        }
        final page = widget.section == 'history'
            ? await _page.fx!.history(_page.start, _page.end)
            : await _page.fx!.entries();
        final items = page.items('items', RemoteJson.new);
        if (widget.section == 'history') {
          for (final row in items) {
            SmsMessage(row.value, _page.fx!.businessId);
          }
        }
        if (mounted && request == _page.generation) {
          {
            _page.rows = items;
            _page.next = page.optionalText('nextCursor');
            _page.update();
          }
        }
      }
    } catch (e) {
      if (mounted && request == _page.generation) {
        {
          _page.error = BusinessSmsFX.messageFor(e);
          _page.update();
        }
        Alert.error(_page.error!);
      }
    } finally {
      if (mounted && request == _page.generation) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> more() async {
    if (_page.next == null || _page.loading || _page.moreLoading) return;
    final cursor = _page.next!, request = _page.generation;
    {
      _page.moreLoading = true;
      _page.update();
    }
    try {
      if (_page.cursors.contains(cursor)) {
        throw const FormatException('Repeated SMS page');
      }
      final page = widget.section == 'history'
          ? await _page.fx!.history(_page.start, _page.end, after: cursor)
          : await _page.fx!.entries(after: cursor);
      final items = page.items('items', RemoteJson.new);
      if (widget.section == 'history') {
        for (final row in items) {
          SmsMessage(row.value, _page.fx!.businessId);
        }
      }
      final after = page.optionalText('nextCursor');
      if (after == cursor || (after != null && _page.cursors.contains(after))) {
        throw const FormatException('Repeated SMS cursor');
      }
      final id = widget.section == 'history' ? 'notificationId' : 'entryId';
      if (items.any(
        (r) => _page.rows.any((old) => old.text(id) == r.text(id)),
      )) {
        throw const FormatException('Duplicate SMS row');
      }
      if (mounted && request == _page.generation) {
        {
          _page.cursors.add(cursor);
          _page.rows.addAll(items);
          _page.next = after;
          _page.update();
        }
      }
    } catch (e) {
      if (mounted && request == _page.generation) {
        Alert.error(BusinessSmsFX.messageFor(e));
      }
    } finally {
      if (mounted && request == _page.generation) {
        _page.moreLoading = false;
        _page.update();
      }
    }
  }

  Future<void> open(String route, Map<String, Object?> arguments) async {
    if (_page.opening) return;
    _page.opening = true;
    try {
      await Get.toNamed(route, arguments: arguments, preventDuplicates: false);
    } finally {
      _page.opening = false;
      if (mounted) await load();
    }
  }

  Future<void> showEvent(String event) async {
    final items = _page.templates.where((t) => t.eventKey == event).toList();
    await MyBottomSheet.view(
      context,
      title: smsEventName(event),
      child: (scroll) => SingleChildScrollView(
        controller: scroll,
        child: Column(
          children: [
            if (event.startsWith('CLUB_'))
              const Text('اتصال خودکار باشگاه مشتریان در سرور فعال نیست.'),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('قالبی تعریف نشده است.'),
              ),
            for (final item in items)
              Column(
                children: [
                  ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.active ? 'فعال' : 'غیرفعال'}${item.isDefault ? ' • پیش‌فرض' : ''}',
                    ),
                    onTap: () {
                      Get.back();
                      open(nav_routes.RoutesName.SMS_TEMPLATE, {
                        'fx': _page.fx!,
                        'eventKey': event,
                        'variables': _page.events[event]!,
                        'template': item,
                      });
                    },
                  ),
                  EndLine(rightPadding: 0),
                ],
              ),
            if (_page.fx!.has('template.create'))
              BTN(
                name: 'قالب جدید',
                icon: IconsaxPlusLinear.add,
                onTap: () {
                  Get.back();
                  open(nav_routes.RoutesName.SMS_TEMPLATE, {
                    'fx': _page.fx!,
                    'eventKey': event,
                    'variables': _page.events[event]!,
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> detail(RemoteJson row) async {
    try {
      final message = await _page.fx!.message(row.text('notificationId'));
      if (!mounted) return;
      final content = message.row.value['content'];
      await MyBottomSheet.view(
        context,
        title: 'جزئیات پیامک',
        child: (scroll) => SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              Text(SmsMessage.statuses[message.status]!),
              MyDivider(),
              Text(
                message.row.optionalText('recipient') ??
                    message.row.text('recipientMasked'),
              ),
              MyDivider(),
              Text(
                content is Map && content['text'] is String
                    ? content['text'] as String
                    : 'متن پیامک در دسترس نیست.',
              ),
              if (message.row.optionalText('lastErrorCode')
                  case final code?) ...[
                MyDivider(),
                Text('کد خطا: $code'),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) Alert.error(BusinessSmsFX.messageFor(e));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_BusinessSmsScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => Main(
      initState: () async => true,
      header: Header.page(context, text: title),
      child: (_) => Column(
        children: [
          if (widget.section == 'events')
            Container(
              height: 122,
              padding: const EdgeInsets.fromLTRB(10, 15, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'اعتبار قابل استفاده',
                          style: TextStyle(fontSize: 16),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _page.wallet == null
                                ? '—'
                                : '${Price.show(_page.wallet!.available)} تومان',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_page.wallet != null)
                          Text(
                            'رزروشده: ${Price.show(_page.wallet!.held)} تومان',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BTN(
                          name: 'اعتبار پیامک',
                          navigate: true,
                          icon: IconsaxPlusLinear.trend_up,
                          onTap: () => open(
                            nav_routes.RoutesName.BUSINESS_SMS,
                            {'appId': widget.appId, 'section': 'wallet'},
                          ),
                        ),
                        BTN(
                          name: 'تاریخچه ارسال',
                          navigate: true,
                          icon: IconsaxPlusLinear.sms_search,
                          onTap: () => open(
                            nav_routes.RoutesName.BUSINESS_SMS,
                            {'appId': widget.appId, 'section': 'history'},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          MyDivider(
            text: widget.section == 'events'
                ? 'قالب‌های رویدادها'
                : widget.section == 'history'
                ? 'پیامک‌های ۷ روز اخیر'
                : 'گردش اعتبار پیامک',
          ),
          if (widget.section == 'wallet') ...[
            Text(
              _page.wallet == null
                  ? 'اعتبار قابل استفاده: —'
                  : 'اعتبار قابل استفاده: ${Price.show(_page.wallet!.available)} تومان',
            ),
            if (_page.fx != null)
              BTN(
                name: 'افزایش اعتبار',
                navigate: true,
                icon: IconsaxPlusLinear.trend_up,
                disabled: _page.loading,
                onTap: () => open(nav_routes.RoutesName.SMS_FUNDING, {'sms': _page.fx!}),
              ),
          ],
          if (_page.fx?.pending != null)
            BTN(
              name: 'پیگیری ثبت قالب قبلی',
              icon: IconsaxPlusLinear.refresh_2,
              onTap: () async {
                try {
                  await _page.fx!.send(_page.fx!.pending!);
                  Alert.success('عملیات قالب با موفقیت ثبت شد.');
                  await load();
                } catch (e) {
                  Alert.error(BusinessSmsFX.messageFor(e));
                }
              },
            ),
          Expanded(
            child: _page.loading
                ? const Center(child: Loader())
                : _page.error != null
                ? Center(child: Text(_page.error!))
                : widget.section == 'events'
                ? ListView(
                    children: [
                      for (final event in _page.events.keys)
                        Column(
                          children: [
                            InkWell(
                              onTap: () => showEvent(event),
                              child: Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        smsEventName(event),
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_page.templates.any(
                                      (t) => t.eventKey == event && t.isDefault,
                                    ))
                                      const Text('پیش‌فرض'),
                                    const Icon(IconsaxPlusLinear.arrow_left_1),
                                  ],
                                ),
                              ),
                            ),
                            EndLine(rightPadding: 0),
                          ],
                        ),
                    ],
                  )
                : _page.rows.isEmpty
                ? const Center(child: Text('اطلاعاتی ثبت نشده است.'))
                : ListView(
                    children: [
                      for (final row in _page.rows)
                        Column(
                          children: [
                            ListTile(
                              onTap: widget.section == 'history'
                                  ? () => detail(row)
                                  : null,
                              title: Text(
                                widget.section == 'history'
                                    ? row.text('recipientMasked')
                                    : '${Price.show(row.number('amount'))} تومان',
                              ),
                              subtitle: Text(
                                widget.section == 'history'
                                    ? SmsMessage.statuses[row.text('status')]!
                                    : '${smsEntryReasons[row.text('reason')] ?? 'گردش اعتبار'} • مانده ${Price.show(row.number('balanceAfter'))} تومان',
                              ),
                              trailing: Text(
                                row.text('createdAt').split('T').first,
                              ),
                            ),
                            EndLine(rightPadding: 0),
                          ],
                        ),
                      if (_page.next != null)
                        BTN(
                          name: 'نمایش بیشتر',
                          inLoad: _page.moreLoading,
                          onTap: more,
                        ),
                    ],
                  ),
          ),
          BTN(
            name: 'دریافت مجدد',
            icon: IconsaxPlusLinear.refresh_2,
            disabled: _page.loading || _page.moreLoading,
            onTap: load,
          ),
        ],
      ),
    ),
  );
}

class SmsTemplateScreen extends StatefulWidget {
  final BusinessSmsFX fx;
  final String eventKey;
  final List<String> variables;
  final SmsTemplate? template;
  const SmsTemplateScreen({
    required this.fx,
    required this.eventKey,
    required this.variables,
    this.template,
    super.key,
  });
  @override
  State<SmsTemplateScreen> createState() => _SmsTemplateScreenState();
}

class _SmsTemplateScreenController extends GetxController {
  _SmsTemplateScreenController(this.widget);
  SmsTemplateScreen widget;
  late final name = TextEditingController(text: widget.template?.name);
  late final body = TextEditingController(text: widget.template?.body);
  late bool active = widget.template?.active ?? true;
  bool saving = false;
}

class _SmsTemplateScreenState extends State<SmsTemplateScreen> {
  late final _page = _SmsTemplateScreenController(widget);

  @override
  void dispose() {
    _page.name.dispose();
    _page.body.dispose();
    super.dispose();
  }

  Future<void> save({bool deleting = false}) async {
    if (_page.saving) return;
    if (widget.fx.pending != null) {
      Alert.error('ابتدا عملیات قبلی را در صفحه پیامک پیگیری کنید.');
      return;
    }
    final item = widget.template;
    if (!deleting) {
      final text = _page.body.text.trim(),
          names = RegExp(r'\{\{([A-Za-z][A-Za-z0-9]*)\}\}')
              .allMatches(text)
              .map((m) => m[1]!);
      final rest = text.replaceAll(RegExp(r'\{\{[A-Za-z][A-Za-z0-9]*\}\}'), '');
      if (_page.name.text.trim().isEmpty ||
          _page.name.text.trim().length > 100 ||
          text.isEmpty ||
          text.length > 1000 ||
          names.any((n) => !widget.variables.contains(n)) ||
          rest.contains('{{') ||
          rest.contains('}}')) {
        Alert.error('نام، متن قالب و متغیرهای مجاز را بررسی کنید.');
        return;
      }
    }
    final command = SmsTemplateCommand(
      deleting
          ? 'DELETE'
          : item == null
          ? 'POST'
          : 'PATCH',
      item == null ? 'templates' : 'templates/${item.id}',
      deleting
          ? {'expectedRevision': item!.revision}
          : {
              'name': _page.name.text.trim(),
              'body': _page.body.text.trim(),
              if (item == null)
                'eventKey': widget.eventKey
              else ...{
                'active': _page.active,
                'expectedRevision': item.revision,
              },
            },
    );
    {
      _page.saving = true;
      _page.update();
    }
    try {
      await widget.fx.send(command);
      if (mounted) {
        Alert.success(
          deleting ? 'قالب با موفقیت حذف شد.' : 'قالب با موفقیت ثبت شد.',
        );
        Get.back();
      }
    } catch (e) {
      if (mounted) Alert.error(BusinessSmsFX.messageFor(e));
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  Future<void> selectDefault() async {
    if (_page.saving) return;
    {
      _page.saving = true;
      _page.update();
    }
    try {
      // Refresh all visible defaults before selecting; this is a different revision from the template revision.
      await widget.fx.authorize();
      final items = await widget.fx.templates();
      final selected = items.where(
        (t) => t.eventKey == widget.eventKey && t.isDefault,
      );
      final revision = selected.isEmpty
          ? 0
          : RemoteJson(selected.single.row.value['default']).number('revision');
      await widget.fx.setDefault(widget.template!, revision);
      if (mounted) {
        Alert.success('قالب پیش‌فرض با موفقیت ثبت شد.');
        Get.back();
      }
    } catch (e) {
      if (mounted) Alert.error(BusinessSmsFX.messageFor(e));
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_SmsTemplateScreenController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final item = widget.template;
        final edit = widget.fx.has(
          item == null ? 'template.create' : 'template.update',
        );
        return Main(
          initState: () async => true,
          header: Header.page(
            context,
            text: item == null ? 'قالب جدید' : item.name,
          ),
          child: (_) => SingleChildScrollView(
            child: Column(
              children: [
                MyDivider(text: smsEventName(widget.eventKey)),
                Input(
                  controller: _page.name,
                  name: 'نام قالب',
                  maxLength: 100,
                  enabled: edit && !_page.saving,
                  require: true,
                ),
                Input(
                  controller: _page.body,
                  name: 'متن قالب',
                  maxLength: 1000,
                  maxLines: 8,
                  minLines: 4,
                  enabled: edit && !_page.saving,
                  require: true,
                ),
                MyDivider(text: 'متغیرهای مجاز'),
                Wrap(
                  children: [
                    for (final variable in widget.variables)
                      MiniBTN(
                        name: '{{$variable}}',
                        icon: IconsaxPlusLinear.add,
                        noFlex: true,
                        onTap: edit && !_page.saving
                            ? () {
                                _page.body.text += '{{$variable}}';
                              }
                            : null,
                      ),
                  ],
                ),
                if (item != null)
                  SwitchListTile(
                    title: const Text('قالب فعال'),
                    value: _page.active,
                    onChanged: edit && !_page.saving
                        ? (v) {
                            _page.active = v;
                            _page.update();
                          }
                        : null,
                  ),
                if (edit)
                  BTN(
                    name: 'ثبت قالب',
                    type: BTNType.ok,
                    disabled: _page.saving,
                    onTap: save,
                  ),
                if (item != null &&
                    item.active &&
                    !item.isDefault &&
                    widget.fx.has('template.default'))
                  BTN(
                    name: 'انتخاب به‌عنوان پیش‌فرض',
                    disabled: _page.saving,
                    onTap: selectDefault,
                  ),
                if (item != null && widget.fx.has('template.delete'))
                  BTN(
                    name: 'حذف قالب',
                    type: BTNType.delete,
                    disabled: _page.saving,
                    onTap: () => Confirm.con(
                      context,
                      type: ConfirmType.DELETE,
                      confirmText: 'حذف قالب',
                      onTapConfirm: () {
                        Get.back();
                        save(deleting: true);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant SmsTemplateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _page.widget = widget;
  }
}

Widget buildSmsTemplateRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return SmsTemplateScreen(
    fx: args.required<BusinessSmsFX>('fx'),
    eventKey: args.required<String>('eventKey'),
    variables: args.required<List<String>>('variables'),
    template: args.optional<SmsTemplate>('template'),
  );
}

Widget buildBusinessSmsRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return BusinessSmsScreen(
    appId: args.optional<String>('appId') ?? 'mik',
    section: args.optional<String>('section') ?? 'events',
  );
}
