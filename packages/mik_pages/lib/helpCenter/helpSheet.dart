import 'package:get/get.dart';
import 'package:mik_components/elements/bottomSheet.dart';
import 'package:mik_pages/helpCenter/helpDetails.dart';

class HelpPageSheet {
  static view(context) async {
    var post = _findPost();
    MyBottomSheet.view(
      context,
      child: (scrollController) => HelpDetailsPage(scrollController: scrollController, postId: post['id']!, postName: post['name']!, header: false),
      title: post['name'] ?? '',
      initialChildSize: 0.7,
      // h: Get.height * 0.8,
    );
  }
}

_findPost() {
  switch (Get.currentRoute) {
    case '/menu/profile': //mik
      return {'name': 'پروفایل', 'id': '6989d786f03baf168307a5ea'};
    //  case '/menu/profile'://mikyar
    // return {'name': 'پروفایل', 'id': '698992da3fe6f03cedd93311'};
    case '/menu/sub':
      return {'name': 'اشتراک', 'id': '6989e349f03baf168307a7af'};
    case '/menu/sub/history':
      return {'name': 'سابقه خرید اشتراک', 'id': '698b1a33f608bfe8185e78cb'};
    case '/menu/settings':
      return {'name': 'تنظیمات', 'id': '6989c42ef03baf1683079924'}; //mik
    //  return {'name': 'تنظیمات', 'id': '698992b93fe6f03cedd932b2'};//mikyar
    case '/menu/refferal':
      return {'name': 'دعوت از دوستان', 'id': '6989c4cdf03baf16830799c0'};
    case '/menu/upgrade':
      return {'name': 'بروزرسانی', 'id': '6989c501f03baf1683079a09'};
    case '/accdept/invoices/add':
      return {'name': 'صدور فاکتور', 'id': '698985913fe6f03cedd91db1'};
    case '/accdept/invoices':
      return {'name': 'لیست فاکتور', 'id': '6989d10df03baf168307a297'};
    case '/SelectProductForInvoice':
      return {'name': 'افزودن به فاکتور', 'id': '698988113fe6f03cedd92099'};
    case '/product/warehouse/transfer/many':
      return {'name': 'جا به جایی محصولات در انبار ها ', 'id': '698989063fe6f03cedd923d4'};
    case '/accdept/invoices/detail':
      return {'name': 'جزییات فاکتور', 'id': '698989513fe6f03cedd92462'};
    case '/products':
      return {'name': 'محصولات', 'id': '698989d03fe6f03cedd924df'};
    case '/product/property/add':
      return {'name': 'افزودن ویژگی', 'id': '69898a8e3fe6f03cedd9264d'};
    case '/product/details':
      return {'name': 'جزییات محصول', 'id': '6989c522f03baf1683079a4a'};
    case '/ProductGroupDetailsScreen':
      return {'name': 'تکمیل جزییات محصولات', 'id': '69898c973fe6f03cedd929fb'};
    case '/ProductGroupAddScreen':
      return {'name': 'افزودن گروهی محصولات', 'id': '69898ac53fe6f03cedd926c5'};
    case '/product/pro':
      return {'name': 'افزودن ویژگی به محصول', 'id': '6989c549f03baf1683079a8b'};
    case '/product/pro/divideinventory':
      return {'name': 'تفکیک موجودی محصول', 'id': '6989e6c0f03baf168307a817'};
    case '/product/price':
      return {'name': 'قیمت‌گذاری محصول', 'id': '6989c57bf03baf1683079acc'};
    case '/CatManageScreen':
      return {'name': 'مدیریت دسته‌بندی‌ها', 'id': '69898b5c3fe6f03cedd9278a'};
    case '/accdept/cheque':
      return {'name': 'چک ها', 'id': '69898bb93fe6f03cedd927f5'};
    case '/accdept/cost':
      return {'name': 'هزینه ها', 'id': '69898c013fe6f03cedd92889'};
    case '/accdept/cost/add':
      return {'name': 'افزودن هزینه', 'id': '6989d1a1f03baf168307a2da'};
    case '/accdept/cost/detail':
      return {'name': 'جزییات هزینه', 'id': '69898c393fe6f03cedd92990'};
    case '/accdept/bill':
      return {'name': 'صورت‌حساب‌ها', 'id': '69898d813fe6f03cedd92bda'};
    case '/mikway/branch':
      return {'name': 'شعب', 'id': '6989c5c6f03baf1683079b19'};
    case '/mikway/branch/add':
      return {'name': 'افزودن شعبه جدید', 'id': '698b1a5af608bfe8185e793a'};
    case '/mikway/mikyar':
      return {'name': 'میکيار', 'id': '6989c5eaf03baf1683079b5a'};
    case '/mikway/mikyar/add':
      return {'name': 'افزودن میکيار', 'id': '6989c708f03baf1683079ce1'};
    case '/mikway/mikyar/detail':
      return {'name': 'جزئیات میکيار', 'id': '6989c730f03baf1683079d27'};
    case '/mikway/mikyar/permission/add':
      return {'name': 'افزودن سطح دسترسی میک‌یار', 'id': '6989c77cf03baf1683079d68'};
    case '/mikway/sms':
      return {'name': 'سامانه اطلاع‌رسانی', 'id': '6989c60ef03baf1683079b9b'};
    case '/mikway/sms/pattern/new':
      return {'name': 'تعریف پترن', 'id': '6989c62bf03baf1683079bdc'};
    case '/mikway/sms/pattern':
      return {'name': 'پترن فعال', 'id': '699ebbedbafd7eaf8b9d5ea5'};
    case '/mikway/sms/creadit':
      return {'name': 'اعتبار پیامک', 'id': '6989c673f03baf1683079c24'};
    case '/mikway/sms/history':
      return {'name': 'تاریخچه ارسال پیامک', 'id': '6989c6c7f03baf1683079c98'};
    case '/mikway/onlinefator':
      return {'name': 'فاکتور آنلاین', 'id': '6989e80cf03baf168307a8ba'};
    case '/smart/ipg':
      return {'name': 'فعال‌سازی پرداخت آنلاین(میکیف)', 'id': '6989e852f03baf168307a918'};
    case '/smart/mikif':
      return {'name': 'مدیریت میکیف', 'id': '699ebbaabafd7eaf8b9d5e2e'};
    case '/smart/mikif/deposit':
      return {'name': 'واریز به کیف پول', 'id': '699ebea3bafd7eaf8b9d5f7e'};
    case '/smart/mikif/widward':
      return {'name': 'برداشت از کیف پول', 'id': '699ebec6bafd7eaf8b9d5fce'};
    case '/smart/mikif/widward/history':
      return {'name': 'تاریخچه برداشت‌ها', 'id': '699ebfdcbafd7eaf8b9d60e7'};
    case '/smart/mikif/history':
      return {'name': 'تاریخچه تراکنش‌ها', 'id': '699ebef5bafd7eaf8b9d6037'};
    case '/mikway/tax/setting':
      return {'name': 'تنظیمات TSP', 'id': '6989c7a0f03baf1683079da9'};
    case '/mikway/api':
      return {'name': 'کلید‌های API', 'id': '6989c83ff03baf1683079e24'};
    case '/mikway/api/add':
      return {'name': 'افزودن کلید API', 'id': '6989c889f03baf1683079e92'};
    case '/mikway/shop':
      return {'name': 'تنظیمات فروشگاه‌ساز', 'id': '6989c8d8f03baf1683079f0c'};
    case '/mikway/bot':
      return {'name': 'میک‌بات', 'id': '6989c8f9f03baf1683079f4d'};
    case '/mikway/marketplace':
      return {'name': 'اتصال به مارکت پلیس‌ها', 'id': '6989c91ff03baf1683079f8e'};
    case '/mikway/storage':
      return {'name': 'اتصال به سامانه‌های انبارش', 'id': '6989c94af03baf1683079fcf'};
    case '/mikway/sites':
      return {'name': 'اتصال به سایت‌ساز‌ها', 'id': '6989c969f03baf168307a010'};
    case '/mikway/sites/woo':
      return {'name': 'اتصال به وردپرس', 'id': '6989c991f03baf168307a051'};
    case '/mikway/sites/mixin':
      return {'name': 'اتصال به میکسین', 'id': '6989ca4af03baf168307a114'};
    case '/mikway/sites/podro':
      return {'name': 'اتصال به پادرو', 'id': '6989ca6cf03baf168307a155'};
    case '/mikway/sites/shopfa':
      return {'name': 'اتصال به شاپفا', 'id': '6989d666f03baf168307a528'};
    case '/mikway/sites/sazito':
      return {'name': 'اتصال به سازیتو', 'id': '6989d508f03baf168307a448'};
    case '/mikway/sites/webzi':
      return {'name': 'اتصال به وب‌زی', 'id': '6989d7d7f03baf168307a670'};
    case '/mikway/sites/bahoosh':
      return {'name': 'اتصال به باهوش', 'id': '6989cacef03baf168307a196'};
    case '/mikway/sites/portal':
      return {'name': 'اتصال به پرتال', 'id': '6989d0d1f03baf168307a24c'};
    case '/mikway/metasearch':
      return {'name': 'اتصال به متاسرچ‌ها', 'id': '6989c9b7f03baf168307a092'};
    case '/mikway/accsoft':
      return {'name': 'اتصال به نرم‌افزارهای حسابداری', 'id': '6989c9f8f03baf168307a0d3'};
    case '/accdept/prttra':
      return {'name': 'سرمایه', 'id': '6989d1c9f03baf168307a31c'};
    case '/crm/customer/':
      return {'name': 'مشتریان', 'id': '69898df43fe6f03cedd92c4d'};
    case '/crm/customer/detail':
      return {'name': 'جزییات مشتری', 'id': '69898e2e3fe6f03cedd92d2a'};
    case '/accdept/persons/add':
      return {'name': 'طرف حساب جدید', 'id': '69898ed03fe6f03cedd92e19'};
    case '/crm/connection':
      return {'name': 'تاریخچه ارتباطات', 'id': '6989901f3fe6f03cedd92ec7'};
    case '/crm/connection/add':
      return {'name': 'ارتباط جدید', 'id': '69898ff93fe6f03cedd92e61'};
    case '/accdept/persons/partners':
      return {'name': 'شرکا', 'id': '6989d1f5f03baf168307a361'};
    case '/accdept/persons/partner/details':
      return {'name': 'جزئیات شرکا', 'id': '6989d234f03baf168307a3a3'};
    case '/accdept/persons/suppliers':
      return {'name': 'تامین کنندگان', 'id': '6989908e3fe6f03cedd92f62'};
    case '/accdept/persons/supplier/details':
      return {'name': 'جزییات تامین کنندگان', 'id': '6989915a3fe6f03cedd92fed'};
    case '/accdept/persons/servicers':
      return {'name': 'سرویس دهندگان', 'id': '6989917e3fe6f03cedd9304f'};
    case '/accdept/persons/servicer/details':
      return {'name': 'جزییات سرویس دهندگان', 'id': '698991b43fe6f03cedd930bc'};
    case '/accdept/reports':
      return {'name': 'گزارشات', 'id': '698991eb3fe6f03cedd93142'};
    case '/accdept/reports/products':
      return {'name': 'گزارش گردش تعدادی', 'id': '698992203fe6f03cedd931a8'};
    case '/accdept/reports/products/detail':
      return {'name': 'نمودار گزارش گردش تعدادی', 'id': '6989c3e5f03baf16830798e9'};
    case '/accdept/reports/profit':
      return {'name': 'سود و زیان', 'id': '698992583fe6f03cedd9320f'};
    default:
  }
}
