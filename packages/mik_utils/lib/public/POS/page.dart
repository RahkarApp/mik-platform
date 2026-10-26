import 'package:mik_router/mik_router.dart' as nav_routes;

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/fx/invoice.dart';
import 'package:mik_data/utils/fx/product.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_utils/public/POS/mikyarpos.dart';
import 'package:mik_utils/public/POS/pos.dart';
import 'package:mik_utils/public/number.dart';
import 'package:mik_utils/public/price.dart';
import 'package:persian_number_utility/persian_number_utility.dart';

// import 'package:pegahsystem/common/components/toast.dart';
import 'package:persian_tools/persian_tools.dart';

class CreateWidgetPring extends StatefulWidget {
  InvoiceDB data;
  double paid;
  CreateWidgetPring({super.key, required this.data, required this.paid});

  @override
  CreateWidgetPringState createState() => CreateWidgetPringState();
}

class CreateWidgetPringState extends State<CreateWidgetPring> {
  final GlobalKey _globalKey = GlobalKey();
  static const pnaChannel = MethodChannel('com.rahkarapp.mikyar/POS');
  Future<void> _captureAndSave() async {
    try {
      // گرفتن تصویر از ویجت
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      ui.Image image = await boundary.toImage(pixelRatio: 2);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      String base64Image = base64Encode(Uint8List.fromList(pngBytes));
      try {
        if (POSFX.detect() == PosModel.i9000S) {
          final res = await pnaChannel
              .invokeMethod(PosEvents.printI9000S, {'image': base64Image});
          // Get.back();
          print('Result: $res');
        }
        if (POSFX.detect() == PosModel.p10) {
          final res = await pnaChannel
              .invokeMethod(PosEvents.printP10, {'image': base64Image});
          // Get.back();
          print('Result: $res');
        } else {
          // Toast.error('این دستگاه پشتیبانی نمیشود');
        }
      } catch (e) {
        print('Print error: $e');
      }
    } catch (e) {
      print('Error: $e');
    }
    Get.back();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 500), () {
        _captureAndSave();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    BillDB? billItem;
    if (!widget.data.type!.startsWith('pf')) {
      billItem = bill.values
          .where((element) => element.uid == widget.data.billUID![0])
          .toList()[0];
    }
    PersonDB personItem = person.values
        .where((element) => element.uid == widget.data.personUID)
        .toList()[0];

    return PopScope(
      // canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('چاپ فاکتور'),
          leading: Container(),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: _globalKey,
            child: Column(
              children: [
                Container(
                    width: 384,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Material(
                      textStyle:
                          TextStyle(fontFamily: 'iran', color: Colors.black),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            !widget.data.type!.startsWith('pf')
                                ? 'فاکتور فروش'
                                : 'پیش فاکتور',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            profile.values.first.name!,
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Container(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.data.type!.startsWith('pf')
                                        ? 'شماره پیش فاکتور: ${widget.data.id}'.toPersianDigit()
                                        : 'شماره فاکتور: ${widget.data.id}'
                                            .toPersianDigit(),
                                    style: TextStyle(
                                        fontSize: 18, fontFamily: 'vazir'),
                                  ),
                                  Text(
                                    'تاریخ: ${widget.data.date.toString().toPersianDate()}'
                                        .toPersianDigit(),
                                    style: TextStyle(
                                        fontSize: 18, fontFamily: 'vazir'),
                                  )
                                ],
                              )),
                          Container(
                            height: 1,
                            color: Colors.black,
                            width: Get.width,
                          ),
                          if (widget.data.personUID != null)
                            Container(
                                decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Colors.black, width: 1))),
                                child: Row(children: [
                                  Container(
                                    width: 60,
                                    height: 80,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        border: Border(
                                            left: BorderSide(
                                                color: Colors.black,
                                                width: 1))),
                                    child: Text(
                                      'خریدار',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Flexible(
                                      fit: FlexFit.tight,
                                      child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 3),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${personItem.name}',
                                                  style:
                                                      TextStyle(fontSize: 20),
                                                ),
                                                Text(
                                                  'تلفن: ${personItem.mobile}'
                                                      .toPersianDigit(),
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontFamily: 'vazir'),
                                                ),
                                              ])))
                                ])),

                          _productList(),
                          // InvoiceFX.find
                          // ProductTable(items: widget.data.items!,productNames: {
                          //   for (var item in widget.data.items!.keys.toList()) item: item['id']
                          // },)
                          // SizedBox(height: 5),
                          _price(),
                          if ((profile.getAt(0)!.slogan ?? '') != '' && widget.data.type!.startsWith('pf'))
                            SizedBox(height: 5),
                          if ((profile.getAt(0)!.slogan ?? '') != '')
                            Container(
                              width: 384,
                              color: Colors.black,
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Text(profile.getAt(0)!.slogan ?? '',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.bold))),
                          // if ((widget.data['text2'] ?? '') != '') SizedBox(height: 5),
                          // if ((widget.data['text2'] ?? '') != '')
                          //   Container(
                          //       padding: EdgeInsets.symmetric(horizontal: 3),
                          //       child: Text(
                          //         widget.data['text2'] ?? '',
                          //         textAlign: TextAlign.justify,
                          //         style: TextStyle(fontSize: 16),
                          //       )),
                          // if ((widget.data['text3'] ?? '') != '') SizedBox(height: 5),
                          // if ((widget.data['text3'] ?? '') != '')
                          //   Container(
                          //       padding: EdgeInsets.symmetric(horizontal: 3),
                          //       child: Text(
                          //         widget.data['text3'] ?? '',
                          //         textAlign: TextAlign.justify,
                          //         style: TextStyle(fontSize: 16),
                          //       )),
                          // if ((widget.data['slug'] ?? '') != '') SizedBox(height: 5),
                          // if ((widget.data['slug'] ?? '') != '')
                          //   Container(
                          //       padding: EdgeInsets.symmetric(horizontal: 3),
                          //       decoration: BoxDecoration(border: Border.all()),
                          //       child: Text(
                          //         widget.data['slug'] ?? '',
                          //         textAlign: TextAlign.justify,
                          //         style: TextStyle(fontSize: 16),
                          //       ))
                        ],
                      ),
                    )),
                // SizedBox(height: 10,),
                Container(
                  width: 384,
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '** ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        'قدرت گرفته از میک',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Image.asset(
                        'assets/images/logo/mikapp.png',
                        width: 30,
                        height: 30,
                      ),
                      Text(
                        ' **',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 120),
                // Image.asset('assets/images/pos/header.jpg', width: Get.width - 5, fit: BoxFit.fitWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _productList() {
    // "showUnit":

    Map<int, TableColumnWidth> columnWidths = {
      0: FlexColumnWidth(3),
      1: FlexColumnWidth(1),
      2: FlexColumnWidth(2),
      3: FlexColumnWidth(3)
    };

    List<ProductDB> products = [];
    List<Map> items = [];

    List itemForPrint = [
      // {
      //   'productName':'',
      //   'propertyName' : '',
      //   'amount':'',
      //   'price':''
      // }
    ];

    for (var item in widget.data.items!.keys.toList()) {
      var myItem = ProductFX.findUID(item.toString());
      for (var value in widget.data.items![item]) {
        var name = ProductFX.proName(item, value['prouid']);
        items.add(value);

        itemForPrint.add({
          'productName': myItem?.name,
          'propertyName': name,
          'amount': value['amount'],
          'price': value['price']
        });
      }

      //  if (myItem != null) {
      //    products.add(myItem);
      //  }
      // items.add(item);
    }
    // for(var item in widget.data.items!.values.toList()) {

    //     // ProductFX.proName(i[], prouid)

    // }
    // print(items);
    // print(widget.data.items);

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: columnWidths,
      children: [
        // ردیف عنوان‌ها
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[300]),
          children: [
            Padding(
              padding: EdgeInsets.all(4),
              child: Text('نام محصول',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text('مقدار',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text('فی',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text('مبلغ کل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
        // ردیف‌های داده‌ها
        for (int i = 0; i < itemForPrint.length; i++)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                    '${itemForPrint[i]['productName']}${itemForPrint[i]['propertyName'] is Container? "" : " |"} ${itemForPrint[i]['propertyName'] is Container ? "" : itemForPrint[i]['propertyName']}',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.right),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                    addCommas(Number.addCommas(itemForPrint[i]['amount']))
                        .toPersianDigit(),
                    style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                    Price.show(itemForPrint[i]['price'] * 10).toPersianDigit(),
                    style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                    Price.show(itemForPrint[i]['amount'] *
                            itemForPrint[i]['price'] *
                            10)
                        .toPersianDigit(),
                    style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
      ],
    );
  }

  _price() {
    var discount = InvoiceFX.discountPrice(widget.data);
    var excess = InvoiceFX.excessPrice(widget.data);
    return Column(
      children: [
        Table(
            border: TableBorder.all(color: Colors.black, width: 1),
            columnWidths: {
              0: FlexColumnWidth(1.94), // ستون عنوان
              1: FlexColumnWidth(3), // ستون مقدار
            },
            children: [
              TableRow(children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('جمع مبلغ',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.right),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                      Price.show(InvoiceFX.price(widget.data) * 10)
                          .toPersianDigit(),
                      style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                      textAlign: TextAlign.center),
                ),
              ]),
              TableRow(children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('تخفیف',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.right),
                ),
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(Price.show(discount).toPersianDigit(),
                      style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                      textAlign: TextAlign.center),
                ),
              ]),
              // TableRow(children: [
              //   Padding(
              //     padding: EdgeInsets.all(4),
              //     child: Text('هزینه اضافی',
              //         style: TextStyle(fontSize: 16),
              //         textAlign: TextAlign.right),
              //   ),
              //   Padding(
              //     padding: EdgeInsets.all(4),
              //     child: Text(Price.show(widget.data.excess! * 10),
              //         style: TextStyle(fontSize: 16),
              //         textAlign: TextAlign.center),
              //   ),
              // ])
            ]),
        // if (widget.data['showPayableTotText'])
        //   Container(
        //     height: 30,
        //     width: Get.width,
        //     padding: EdgeInsets.symmetric(horizontal: 3),
        //     alignment: Alignment.center,
        //     decoration: BoxDecoration(border: Border(bottom: BorderSide())),
        //     child: Text(
        //         '${int.parse((widget.data['payableTot'] ?? 0).toString().split('.')[0]).convertNumToWords()} ریال',
        //         style: TextStyle(fontSize: 16),
        //         textAlign: TextAlign.right),
        //   ),
        Container(
          padding: EdgeInsets.only(right: 5),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 10,
              children: [
                Text(
                    widget.data.type!.startsWith('pf')
                        ? 'جمع کل'
                        : 'مبلغ قابل پرداخت:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.right),
                Flexible(
                    fit: FlexFit.tight,
                    child: Container(
                      alignment: Alignment.center,
                      height: 40,
                      color: Colors.black,
                      child: Text(
                          '${Price.show((InvoiceFX.price(widget.data) - discount) * 10)} ریال'
                              .toPersianDigit(),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontFamily: 'vazir',
                              fontWeight: FontWeight.bold)),
                    ))
              ]),
        ),
        // Container(height: 1,width: Get.width,color: Colors.black,)
        if (widget.data.type!.startsWith('pf'))
          Text(
            '** اعتبار پیش فاکتور تا ${settingsData.values.first.dayForPreFactor} پس از صدور میباشد **',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
       
        if (!widget.data.type!.startsWith('pf'))
          Table(
              border: TableBorder.all(color: Colors.black, width: 1),
              columnWidths: {
                0: FlexColumnWidth(1.94), // ستون عنوان
                1: FlexColumnWidth(3), // ستون مقدار
              },
              children: [
                TableRow(children: [
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('پرداخت شده: ',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                        '${Price.show(widget.paid * 10)} ریال'.toPersianDigit(),
                        style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                        textAlign: TextAlign.center),
                  ),
                ]),
                TableRow(children: [
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text('مانده: ',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                        '${Price.show((InvoiceFX.price(widget.data) - discount + excess - widget.paid) * 10)} ریال'
                            .toPersianDigit(),
                        style: TextStyle(fontSize: 16, fontFamily: 'vazir'),
                        textAlign: TextAlign.center),
                  ),
                ]),
              ]),
      ],
    );
  }

  TableRow _buildPriceRow(String title, String value) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            title,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.right,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            value,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class ProductTable extends StatelessWidget {
  final Map<dynamic, dynamic> items;

  /// optional map of productId -> productName
  final Map<String, String>? productNames;

  const ProductTable({
    Key? key,
    required this.items,
    this.productNames,
  }) : super(key: key);

  String _fmtNum(num? value) {
    if (value == null) return '0';
    final s = value.toInt().toString();
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  String _variantLabel(List<dynamic>? params) {
    if (params == null || params.isEmpty) return '';
    // params assumed to be list of maps like {name:..., value:...} or simple strings
    final parts = params.map((p) {
      if (p is Map) {
        if (p.containsKey('name') && p.containsKey('value')) {
          return '${p['name']}: ${p['value']}';
        } else {
          return p.toString();
        }
      }
      return p.toString();
    }).toList();
    return ' (${parts.join(', ')})';
  }

  @override
  Widget build(BuildContext context) {
    // build rows list
    final rows = <TableRow>[];

    // header row
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.grey[300]),
        children: [
          Padding(
            padding: EdgeInsets.all(4),
            child: Text('نام محصول',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.right),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: Text('مقدار',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: Text('فی',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: Text('مبلغ کل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );

    // data rows
    items.forEach((productId, variants) {
      final baseName =
          productNames != null && productNames!.containsKey(productId)
              ? productNames![productId]!
              : productId;

      for (final v in variants) {
        final price = (v['price'] is num)
            ? v['price'] as num
            : num.tryParse('${v['price']}') ?? 0;
        final amount = (v['amount'] is num)
            ? v['amount'] as num
            : num.tryParse('${v['amount']}') ?? 0;
        final params = v['parameters'] as List<dynamic>?;
        final name =
            baseName + _variantLabel(params); // show variant details after name
        final total = price * amount;

        rows.add(
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(name,
                    style: TextStyle(fontSize: 16), textAlign: TextAlign.right),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(_fmtNum(amount),
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(_fmtNum(price),
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Text(_fmtNum(total),
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        );
      }
    });

    // default column widths (you can pass custom if needed)
    final columnWidths = {
      0: FlexColumnWidth(4),
      1: FlexColumnWidth(2),
      2: FlexColumnWidth(2),
      3: FlexColumnWidth(3),
    };

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: columnWidths,
      children: rows,
    );
  }
}

Widget buildCreateWidgetPringRoute(RouteSettings settings) {
  final args = nav_routes.RouteArguments(settings);
  return CreateWidgetPring(
    data: args.required<InvoiceDB>('data'),
    paid: args.required<double>('paid'),
  );
}
