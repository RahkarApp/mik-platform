part of '../screen.dart';

/// Keeps the existing row layout without converting server UUIDs to legacy Hive IDs.
class PimProductItem extends StatefulWidget {
  final PimProduct item;
  final String categories;
  final bool isLast;
  final ProductFactsFX? facts;
  final VoidCallback? onTap;
  const PimProductItem(
    this.item, {
    super.key,
    required this.categories,
    this.isLast = false,
    this.facts,
    this.onTap,
  });

  @override
  State<PimProductItem> createState() => _PimProductItemState();
}

class _PimProductItemController extends GetxController {
  ProductFacts? facts;
  Object? error;
  bool loading = false;
  int generation = 0;
  Future<void> load(ProductFactsFX? source, PimProduct item) async {
    final request = ++generation;
    loading = source != null;
    facts = null;
    error = null;
    try {
      final result = await source?.load(item);
      if (isClosed || request != generation) return;
      facts = result;
    } catch (failure) {
      if (isClosed || request != generation) return;
      error = failure;
    } finally {
      if (!isClosed && request == generation) {
        loading = false;
        update();
      }
    }
  }
}

class _PimProductItemState extends State<PimProductItem> {
  late final _page = _PimProductItemController();

  PimProduct get item => widget.item;
  @override
  void initState() {
    super.initState();
    _page.load(widget.facts, item);
  }

  @override
  void didUpdateWidget(PimProductItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != item.id ||
        oldWidget.item.revision != item.revision ||
        !identical(oldWidget.facts, widget.facts)) {
      _page.load(widget.facts, item);
    }
  }

  void _refresh() {
    _page.load(widget.facts, item);
    _page.update();
  }

  String _formatQuantity(String value) {
    final parts = value.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$whole${parts.length == 1 ? '' : '.${parts[1]}'}';
  }

  Widget _factsRow() => GetBuilder<_PimProductItemController>(
    init: _page,
    global: false,
    autoRemove: false,
    builder: (_) {
      final pending = _page.loading;
      final data = _page.facts;
      final failure = _page.error == null
          ? null
          : ProductFactsFX.message(_page.error!);
      final price = data?.price;
      final stock = data?.stock;
      final amount = price?.minimum == null
          ? '—'
          : price!.minimum == price.maximum
          ? '${Number.addCommas(price.minimum!)} تومان'
          : '${Number.addCommas(price.minimum!)} - ${Number.addCommas(price.maximum!)} تومان';
      final quantity = stock?.available == null
          ? '—'
          : _formatQuantity(stock!.available.toString());
      final priceText = 'قیمت: ${pending ? '…' : amount}';
      final stockText = 'قابل فروش: ${pending ? '…' : quantity}';
      final priceHint =
          failure ??
          price?.message ??
          '$priceText؛ همهٔ عنوان‌های قیمت معتبر و تنوع‌های فعال';
      final stockHint =
          failure ??
          stock?.message ??
          '$stockText؛ انبار پیش‌فرض شعبه${stock?.blockedForCount == true ? '؛ انبارگردانی باز است.' : ''}';
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Tooltip(
              message: stockHint,
              child: InkWell(
                onTap: pending ? null : _refresh,
                child: Text(
                  stockText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(left: 10),
              child: Tooltip(
                message: priceHint,
                child: InkWell(
                  onTap: pending ? null : _refresh,
                  child: Text(
                    priceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => GetBuilder<_PimProductItemController>(
    init: _page,
    global: false,
    dispose: (state) => state.controller?.onDelete(),
    builder: (_) => InkWell(
      onTap: widget.onTap,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 10),
              ProductImage.img(
                context,
                item,
                70,
                showAll: true,
                business: widget.facts?.pim.context,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Icon(
                                IconsaxPlusLinear.box,
                                size: 20,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: TextScroll(
                                  item.name,
                                  pauseBetween: const Duration(seconds: 1),
                                  velocity: const Velocity(
                                    pixelsPerSecond: Offset(40, 0),
                                  ),
                                  numberOfReps: 2,
                                  mode: TextScrollMode.endless,
                                  intervalSpaces: 10,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 10),
                          width: 110,
                          child: Tooltip(
                            message: item.id,
                            child: Text(
                              'کد: ${item.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      spacing: 5,
                      children: [
                        Icon(
                          IconsaxPlusLinear.category,
                          size: 15,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        Flexible(
                          child: TextScroll(
                            widget.categories.isEmpty ? '—' : widget.categories,
                            pauseBetween: const Duration(seconds: 1),
                            velocity: const Velocity(
                              pixelsPerSecond: Offset(40, 0),
                            ),
                            numberOfReps: 2,
                            mode: TextScrollMode.endless,
                            textDirection: TextDirection.rtl,
                            intervalSpaces: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _factsRow(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          EndLine(),
          SizedBox(height: widget.isLast ? 60 : 5),
        ],
      ),
    ),
  );
}
