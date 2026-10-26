import 'package:mik_router/mik_router.dart' as nav_routes;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/divider.dart';
import 'package:mik_components/base/empty.dart';
import 'package:mik_components/base/endLine.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/myTabbar.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/utils/fx/business_context.dart';
import 'package:mik_data/utils/fx/financial_reports.dart';
import 'package:mik_data/utils/fx/payment_list.dart';
import 'package:mik_utils/public/date.dart';

import '../reports/financial_screen.dart' show financialMoney;

class RemoteBillScreen extends StatefulWidget {
  final String appId;
  const RemoteBillScreen({required this.appId, super.key});
  @override
  State<RemoteBillScreen> createState() => _RemoteBillScreenState();
}

class _RemoteBillScreenController extends GetxController {
  PaymentListFX? fx;
  List<ListedPayment> rows = [];
  bool loading = true, opening = false;
  String? error;
  int index = 0, generation = 0;
}

class _RemoteBillScreenState extends State<RemoteBillScreen> {
  late final _page = _RemoteBillScreenController();

  static const methods = {
    'CASH': 'نقدی',
    'CARD': 'کارت',
    'BANK_TRANSFER': 'انتقال بانکی',
    'CHEQUE': 'چک',
    'ONLINE': 'آنلاین',
  };
  static const statuses = {
    'PENDING': 'در انتظار',
    'CONFIRMED': 'تأییدشده',
    'BOUNCED': 'برگشتی',
    'RETURNED': 'عودت‌شده',
    'REVERSED': 'معکوس‌شده',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  @override
  void dispose() {
    _page.generation++;
    super.dispose();
  }

  Future<void> load() async {
    final request = ++_page.generation;
    {
      _page.loading = true;
      _page.error = null;
      _page.rows = [];
      _page.update();
    }
    try {
      final active = BusinessContext.forApp(widget.appId);
      if (active == null) throw const AuthError(401, 'SESSION_INVALID');
      _page.fx ??= PaymentListFX(active);
      final result = await _page.fx!.load(
        isActive: () => mounted && _page.generation == request,
      );
      if (mounted && _page.generation == request) {
        _page.rows = result;
        _page.update();
      }
    } catch (failure) {
      if (mounted && _page.generation == request) {
        {
          _page.error = FinancialReportsFX.message(failure);
          _page.update();
        }
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted && _page.generation == request) {
        _page.loading = false;
        _page.update();
      }
    }
  }

  Future<void> details(ListedPayment row) async {
    if (_page.opening || _page.loading) return;
    {
      _page.opening = true;
      _page.update();
    }
    try {
      final result = await _page.fx!.detail(row.payment.id);
      if (!mounted) return;
      final payment = result.payment;
      if (payment.partyId != row.payment.partyId ||
          payment.partyType != row.payment.partyType) {
        throw const FormatException('Unexpected payment party');
      }
      {
        _page.opening = false;
        _page.update();
      }
      await MyBottomSheet.view(
        context,
        title: 'جزئیات ${payment.direction == 'IN' ? 'دریافت' : 'پرداخت'}',
        child: (controller) => SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              pair('مبلغ', financialMoney(payment.amount)),
              pair('روش', methods[payment.method]!),
              pair('وضعیت', statuses[payment.status]!),
              pair(
                'طرف حساب',
                payment.partyType == 'CUSTOMER' ? 'مشتری' : 'تأمین‌کننده',
              ),
              pair(
                'نوع عملیات',
                const {
                  'SETTLEMENT': 'تسویه',
                  'REFUND': 'استرداد وجه',
                  'REVERSAL': 'برگشت پرداخت',
                }[result.purpose]!,
              ),
              if (result.reference != null)
                pair('شماره پیگیری', result.reference!),
              if (result.note != null) pair('توضیحات', result.note!),
              MyDivider(),
              SelectableText('شناسه پرداخت: ${payment.id}'),
              SelectableText('شناسه طرف حساب: ${payment.partyId}'),
              SelectableText('شناسه شعبه: ${payment.branchId}'),
              if (_page.fx!.canReadAccount)
                MiniBTN(
                  name: 'صورت‌حساب و گردش حساب',
                  icon: IconsaxPlusLinear.document_text,
                  noFlex: true,
                  onTap: () {
                    Get.back();
                    Get.toNamed(
                      nav_routes.RoutesName.PARTY_ACCOUNT,
                      arguments: {
                        'appId': widget.appId,
                        'partyType': payment.partyType,
                        'partyId': payment.partyId,
                      },
                      preventDuplicates: false,
                    );
                  },
                ),
              BTN(name: 'بستن', onTap: () => Get.back()),
            ],
          ),
        ),
      );
    } catch (failure) {
      if (mounted) {
        {
          _page.rows = [];
          _page.error = FinancialReportsFX.message(failure);
          _page.update();
        }
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.opening = false;
        _page.update();
      }
    }
  }

  Widget pair(String label, String value) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    return GetBuilder<_RemoteBillScreenController>(
      init: _page,
      global: false,
      dispose: (state) => state.controller?.onDelete(),
      builder: (_) {
        final visible = _page.rows
            .where(
              (r) => r.payment.direction == (_page.index == 0 ? 'IN' : 'OUT'),
            )
            .toList();
        return Main(
          initState: () async => '',
          header: Header.page(context, isBack: false, text: 'صورت‌حساب‌ها'),
          child: (_) => Column(
            children: [
              MyTabBar(
                tabs: const ['دریافت', 'پرداخت'],
                currentIndex: _page.index,
                divider: false,
                index: (i) {
                  _page.index = i as int;
                  _page.update();
                },
              ),
              const Text(
                'دریافت و پرداخت مشتریان و تأمین‌کنندگان؛ همه شعب',
                textAlign: TextAlign.center,
              ),
              if (_page.loading || _page.opening)
                const LinearProgressIndicator(),
              if (_page.error != null)
                Text(_page.error!, textAlign: TextAlign.center),
              MiniBTN(
                name: 'دریافت مجدد',
                noFlex: true,
                icon: IconsaxPlusLinear.refresh,
                onTap: _page.loading || _page.opening ? null : load,
              ),
              Expanded(
                child: visible.isEmpty
                    ? _page.loading || _page.error != null
                          ? const SizedBox.shrink()
                          : EmptyList(
                              icon: IconsaxPlusLinear.document_text,
                              text:
                                  'هیچ ${_page.index == 0 ? 'دریافتی' : 'پرداختی'} ثبت نشده است!',
                            )
                    : RefreshIndicator(
                        onRefresh: load,
                        child: ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (_, i) {
                            final row = visible[i], p = row.payment;
                            return Column(
                              children: [
                                InkWell(
                                  key: ValueKey(p.id),
                                  onTap: () => details(row),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      children: [
                                        pair(
                                          '${p.partyType == 'CUSTOMER' ? 'مشتری' : 'تأمین‌کننده'} • ${methods[p.method]}',
                                          financialMoney(p.amount),
                                        ),
                                        pair(
                                          DateConvertor.grigoriToJalali(
                                            row.createdAt,
                                          ),
                                          statuses[p.status]!,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (i != visible.length - 1) EndLine(),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
