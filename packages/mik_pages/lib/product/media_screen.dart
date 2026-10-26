import 'package:mik_router/mik_router.dart' as nav_routes;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_components/elements/buttons/miniButton.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/elements/input/imageSelector.dart';
import 'package:mik_components/elements/productImage.dart';
import 'package:mik_data/source/remote/auth_error.dart';
import 'package:mik_data/source/remote/models/models.dart';
import 'package:mik_data/utils/fx/pim.dart';
import 'package:mik_data/utils/fx/product_media.dart';

class ProductMediaScreen extends StatefulWidget {
  final PimFX fx;
  final String productId;
  const ProductMediaScreen({
    super.key,
    required this.fx,
    required this.productId,
  });
  @override
  State<ProductMediaScreen> createState() => _ProductMediaScreenState();
}

class _ProductMediaScreenController extends GetxController {
  PimProduct? product;
  List<PimMedia> rows = [];
  PimCommand? command;
  bool loading = true, saving = false, conflict = false, uploadPending = false;
  String? error;
  final paths = <String>[].obs, names = <String>[].obs;
  final bytes = <Uint8List>[].obs;
}

class _ProductMediaScreenState extends State<ProductMediaScreen> {
  late final _page = _ProductMediaScreenController();

  late final media = ProductMediaFX.forContext(widget.fx.context);

  bool get canEdit =>
      _page.product != null &&
      _page.product!.status != 'ARCHIVED' &&
      widget.fx.has('pim.product.update') &&
      widget.fx.has('pim.product.shop.update');
  bool get canUpload =>
      canEdit &&
      widget.fx.has('media.file.upload') &&
      widget.fx.has('media.file.read');
  bool get locked =>
      _page.loading || _page.saving || _page.command != null || _page.conflict;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<Object> load() async {
    {
      _page.loading = true;
      _page.error = null;
      _page.conflict = false;
      _page.product = null;
      _page.rows = [];
      _page.update();
    }
    try {
      await widget.fx.authorize();
      final item = await widget.fx.get(
        PimResource.products,
        widget.productId,
      ) as PimProduct;
      final pending = await widget.fx.restore();
      if (pending != null &&
          (pending.resource != PimResource.products ||
              pending.id != item.id ||
              pending.operation != 'update' ||
              pending.body.keys.any(
                (k) => !['media', 'expectedRevision'].contains(k),
              ))) {
        throw const AuthError(409, 'PIM_PENDING');
      }
      final upload = await media.restore(item.id);
      if (mounted) {
        {
          _page.product = item;
          _page.command = pending;
          _page.uploadPending = upload != null;
          _page.rows = [...item.media]
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          _page.update();
        }
      }
    } catch (failure) {
      if (mounted) {
        _page.error = message(failure);
        Alert.error(_page.error!, context: context);
      }
    } finally {
      if (mounted) {
        _page.loading = false;
        _page.update();
      }
    }
    return '';
  }

  String message(Object failure) =>
      failure is AuthError &&
          ['REVISION_CONFLICT', 'PIM_PENDING'].contains(failure.code)
      ? PimFX.message(failure)
      : ProductMediaFX.message(failure);
  Future<void> save() async {
    if (_page.loading ||
        _page.saving ||
        _page.conflict ||
        _page.product == null ||
        !canEdit)
      return;
    {
      _page.saving = true;
      _page.error = null;
      _page.update();
    }
    try {
      if (_page.command == null) {
        final draft = [..._page.rows];
        if (_page.bytes.isNotEmpty || _page.uploadPending) {
          if (!canUpload) throw const AuthError(403, 'FORBIDDEN');
          final id = await media.upload(
            _page.product!.id,
            bytes: _page.bytes.firstOrNull,
            name: _page.names.firstOrNull,
          );
          if (!draft.any((r) => r.mediaId == id)) {
            draft.add(
              PimMedia.fromJson({'mediaId': id, 'sortOrder': draft.length}),
            );
          }
        }
        if (draft.length > 50) {
          throw StateError('حداکثر ۵۰ عکس به محصول متصل می‌شود.');
        }
        final body = [
          for (var i = 0; i < draft.length; i++)
            {
              'mediaId': draft[i].mediaId,
              if (draft[i].alt != null) 'alt': draft[i].alt,
              'sortOrder': i,
            },
        ];
        _page.command = widget.fx.change(PimResource.products, {
          'media': body,
        }, item: _page.product);
      }
      final result = await widget.fx.execute(_page.command!);
      final saved = result.item;
      final expected = (_page.command!.body['media'] as List)
          .map((r) => r['mediaId'])
          .toList();
      if (saved is! PimProduct ||
          saved.id != widget.productId ||
          saved.revision <= (_page.command!.body['expectedRevision'] as int) ||
          saved.media.length != expected.length ||
          saved.media.asMap().entries.any(
            (e) => e.value.mediaId != expected[e.key],
          )) {
        throw const FormatException('Product images not confirmed');
      }
      await media.clear(saved.id);
      if (!mounted) return;
      _page.command = null;
      _page.uploadPending = false;
      _page.paths.clear();
      _page.names.clear();
      _page.bytes.clear();
      Alert.success('تصاویر محصول با موفقیت ثبت شد.');
      Get.back(result: true);
    } catch (failure) {
      if (!mounted) return;
      if (failure is AuthError && widget.fx.pending == null)
        _page.command = null;
      _page.conflict =
          failure is AuthError && failure.code == 'REVISION_CONFLICT';
      _page.error = message(failure);
      try {
        _page.uploadPending = await media.restore(widget.productId) != null;
      } catch (_) {
        /* Keep the original failure visible. */
      }
      if (mounted) Alert.error(_page.error!, context: context);
    } finally {
      if (mounted) {
        _page.saving = false;
        _page.update();
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => GetBuilder<_ProductMediaScreenController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => PopScope(
      canPop: !_page.saving,
      child: Main(
        initState: () async => '',
        header: Header.page(context, text: 'تصاویر محصول'),
        child: (_) => ListView(
          padding: const EdgeInsets.all(10),
          children: [
            if (_page.loading || _page.saving) const LinearProgressIndicator(),
            if (_page.product != null)
              Text(
                _page.product!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            if (_page.error != null) Text(_page.error!),
            if (_page.error != null && !_page.saving)
              BTN(name: 'دریافت نسخه جدید', onTap: load),
            if (_page.command != null)
              const Text(
                'ثبت قبلی تعیین تکلیف نشده است؛ همان درخواست پیگیری می‌شود.',
              ),
            if (_page.uploadPending)
              const Text(
                'بارگذاری قبلی باقی مانده است؛ ثبت را پیگیری کنید. اگر فایل دریافت نشده، همان عکس قبلی را دوباره انتخاب کنید.',
              ),
            if (_page.product != null) ...[
              for (var i = 0; i < _page.rows.length; i++)
                Row(
                  children: [
                    ProductImage.remote(
                      context,
                      _page.product!,
                      70,
                      business: widget.fx.context,
                      media: [_page.rows[i]],
                      showAll: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(i == 0 ? 'عکس اصلی' : 'عکس ${i + 1}')),
                    if (canEdit) ...[
                      if (i > 0)
                        MiniBTN(
                          name: 'اصلی شود',
                          noFlex: true,
                          icon: IconsaxPlusLinear.star,
                          onTap: locked
                              ? null
                              : () {
                                  final row = _page.rows.removeAt(i);
                                  _page.rows.insert(0, row);
                                  _page.update();
                                },
                        ),
                      MiniBTN(
                        name: 'حذف',
                        noFlex: true,
                        icon: IconsaxPlusLinear.trash,
                        onTap: locked
                            ? null
                            : () {
                                _page.rows.removeAt(i);
                                _page.update();
                              },
                      ),
                    ],
                  ],
                ),
              if (canUpload && _page.rows.length < 50)
                IgnorePointer(
                  ignoring: locked,
                  child: ImageSelector(
                    remote: true,
                    name: 'افزودن عکس',
                    list: _page.paths,
                    imgSelectName: _page.names,
                    imgSelectBytes: _page.bytes,
                    callback: (selected, fileNames, data) =>
                        _page.paths.assignAll(List<String>.from(selected)),
                  ),
                ),
              if (!canUpload)
                const Text(
                  'افزودن عکس به مجوز بارگذاری و خواندن فایل و ویرایش محتوای محصول نیاز دارد.',
                ),
              if (canEdit)
                BTN(
                  name: _page.command != null
                      ? 'پیگیری ثبت تصاویر'
                      : 'ثبت تصاویر',
                  disabled: _page.loading || _page.saving || _page.conflict,
                  onTap: save,
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget buildProductMediaRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return ProductMediaScreen(
    fx: args.required<PimFX>('fx'),
    productId: args.required<String>('productId'),
  );
}
