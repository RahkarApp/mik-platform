import 'dart:convert';

/// Stable permission keys. Legacy indices match the MiKYar permission table.
abstract final class PermissionsName {
  static const productsMenu = 'products.menu';
  static const productsCreate = 'products.create';
  static const productsImport = 'products.import';
  static const productsEdit = 'products.edit';
  static const productsShopEdit = 'products.shop.edit';
  static const productsDelete = 'products.delete';
  static const productsCategoriesCreate = 'products.categories.create';
  static const productsMarketplaceSend = 'products.marketplace.send';
  static const productsCategoriesDelete = 'products.categories.delete';
  static const customersMenu = 'customers.menu';
  static const customersCreate = 'customers.create';
  static const customersImport = 'customers.import';
  static const customersView = 'customers.view';
  static const customersViewAll = 'customers.view.all';
  static const customersEdit = 'customers.edit';
  static const customersEditAll = 'customers.edit.all';
  static const invoicesSellCreate = 'invoices.sell.create';
  static const invoicesSellCustomersAll = 'invoices.sell.customers.all';
  static const invoicesSellCustomersAssigned =
      'invoices.sell.customers.assigned';
  static const invoicesSellView = 'invoices.sell.view';
  static const invoicesSellEdit = 'invoices.sell.edit';
  static const invoicesSellStatusReady = 'invoices.sell.status.ready';
  static const invoicesSellStatusSent = 'invoices.sell.status.sent';
  static const invoicesSellStatusCancelled = 'invoices.sell.status.cancelled';
  static const invoicesSellStatusReturned = 'invoices.sell.status.returned';
  static const invoicesSellStatusDelivered = 'invoices.sell.status.delivered';
  static const invoicesSellDiscountApply = 'invoices.sell.discount.apply';
  static const invoicesSellChargesApply = 'invoices.sell.charges.apply';
  static const invoicesSellPaymentReceive = 'invoices.sell.payment.receive';
  static const invoicesSellPaymentOnline = 'invoices.sell.payment.online';
  static const invoicesSellChequeReceive = 'invoices.sell.cheque.receive';
  static const invoicesSellViewAll = 'invoices.sell.view.all';
  static const invoicesSellEditAll = 'invoices.sell.edit.all';
  static const invoicesPreCreate = 'invoices.pre.create';
  static const invoicesPreView = 'invoices.pre.view';
  static const invoicesPreEdit = 'invoices.pre.edit';
  static const invoicesPreConvert = 'invoices.pre.convert';
  static const invoicesPreViewAll = 'invoices.pre.view.all';
  static const invoicesPreEditAll = 'invoices.pre.edit.all';
  static const invoicesPreConvertAll = 'invoices.pre.convert.all';
  static const suppliersMenu = 'suppliers.menu';
  static const suppliersCreate = 'suppliers.create';
  static const suppliersImport = 'suppliers.import';
  static const suppliersView = 'suppliers.view';
  static const suppliersEdit = 'suppliers.edit';
  static const suppliersViewAll = 'suppliers.view.all';
  static const suppliersEditAll = 'suppliers.edit.all';
  static const invoicesBuyCreate = 'invoices.buy.create';
  static const invoicesBuyView = 'invoices.buy.view';
  static const invoicesBuyEdit = 'invoices.buy.edit';
  static const invoicesBuyDelete = 'invoices.buy.delete';
  static const invoicesBuyPaymentPay = 'invoices.buy.payment.pay';
  static const invoicesBuyChequePay = 'invoices.buy.cheque.pay';
  static const invoicesBuyViewAll = 'invoices.buy.view.all';
  static const invoicesBuyEditAll = 'invoices.buy.edit.all';
  static const invoicesBuyDeleteAll = 'invoices.buy.delete.all';
  static const servicersMenu = 'servicers.menu';
  static const servicersCreate = 'servicers.create';
  static const servicersImport = 'servicers.import';
  static const servicersView = 'servicers.view';
  static const servicersEdit = 'servicers.edit';
  static const servicersViewAll = 'servicers.view.all';
  static const servicersEditAll = 'servicers.edit.all';
  static const costsCreate = 'costs.create';
  static const costsView = 'costs.view';
  static const costsEdit = 'costs.edit';
  static const costsCategoriesCreate = 'costs.categories.create';
  static const costsPaymentPay = 'costs.payment.pay';
  static const costsChequePay = 'costs.cheque.pay';
  static const costsShippingView = 'costs.shipping.view';
  static const costsViewAll = 'costs.view.all';
  static const costsEditAll = 'costs.edit.all';
  static const costsShippingViewAll = 'costs.shipping.view.all';
  static const costsDelete = 'costs.delete';
  static const costsDeleteAll = 'costs.delete.all';
  static const chequesMenu = 'cheques.menu';
  static const chequesView = 'cheques.view';
  static const chequesEdit = 'cheques.edit';
  static const chequesClear = 'cheques.clear';
  static const chequesDelete = 'cheques.delete';
  static const chequesViewAll = 'cheques.view.all';
  static const chequesEditAll = 'cheques.edit.all';
  static const chequesClearAll = 'cheques.clear.all';
  static const chequesDeleteAll = 'cheques.delete.all';
  static const warehousesMenu = 'warehouses.menu';
  static const warehousesView = 'warehouses.view';
  static const warehousesCreate = 'warehouses.create';
  static const warehousesEdit = 'warehouses.edit';
  static const warehousesDelete = 'warehouses.delete';
  static const warehousesStocktake = 'warehouses.stocktake';
  static const warehousesTransfer = 'warehouses.transfer';
  static const distributionMenu = 'distribution.menu';
  static const distributionRoute = 'distribution.route';
  static const staffMenu = 'staff.menu';
  static const staffCreate = 'staff.create';
  static const staffView = 'staff.view';
  static const staffEdit = 'staff.edit';
  static const staffPermissionsEdit = 'staff.permissions.edit';
  static const staffPerformanceView = 'staff.performance.view';
  static const rolesView = 'roles.view';
  static const rolesEdit = 'roles.edit';
  static const reportsProfitView = 'reports.profit.view';
  static const reportsQuantityView = 'reports.quantity.view';
  static const crmView = 'crm.view';
  static const crmCreate = 'crm.create';
  static const crmViewAll = 'crm.view.all';
  static const crmEdit = 'crm.edit';
  static const crmEditAll = 'crm.edit.all';
  static const smsMenu = 'sms.menu';
  static const smsPatternsView = 'sms.patterns.view';
  static const smsPatternsCreate = 'sms.patterns.create';
  static const smsPatternsEdit = 'sms.patterns.edit';
  static const smsPatternsViewAll = 'sms.patterns.view.all';
  static const smsPatternsEditAll = 'sms.patterns.edit.all';
  static const smsHistoryView = 'sms.history.view';
  static const smsBalanceView = 'sms.balance.view';
  static const smsBalanceTopup = 'sms.balance.topup';
  static const accountsMenu = 'accounts.menu';
  static const productsPropertiesCreate = 'products.properties.create';
  static const productsPropertiesEdit = 'products.properties.edit';
  static const productsPropertiesDelete = 'products.properties.delete';
  static const productsPropertiesEditAll = 'products.properties.edit.all';
  static const productsPropertiesDeleteAll = 'products.properties.delete.all';
  static const productsPropertiesAssign = 'products.properties.assign';
  static const productsPricesCreate = 'products.prices.create';
  static const productsPricesEdit = 'products.prices.edit';
  static const productsPricesDelete = 'products.prices.delete';
  static const productsPricesEditAll = 'products.prices.edit.all';
  static const productsPricesDeleteAll = 'products.prices.delete.all';
  static const productsPricesDefaultSet = 'products.prices.default.set';
}

class PermissionDefinition {
  final int legacyIndex;
  final String name, group, label;
  final String? requiredName;
  const PermissionDefinition(
    this.legacyIndex,
    this.name,
    this.group,
    this.label, {
    this.requiredName,
  });
}

abstract final class PermissionCatalog {
  static const legacyCount = 211;
  static const definitions = <PermissionDefinition>[
    PermissionDefinition(
      1,
      PermissionsName.productsMenu,
      'محصولات',
      'مشاهده منو',
    ),
    PermissionDefinition(
      2,
      PermissionsName.productsCreate,
      'محصولات',
      'افزودن محصول',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      3,
      PermissionsName.productsImport,
      'محصولات',
      'افزودن از اکسل',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      4,
      PermissionsName.productsEdit,
      'محصولات',
      'ویرایش',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      5,
      PermissionsName.productsShopEdit,
      'محصولات',
      'ویرایش اطلاعات شاپ',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      6,
      PermissionsName.productsDelete,
      'محصولات',
      'حذف/آرشیو',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      7,
      PermissionsName.productsCategoriesCreate,
      'محصولات',
      'افزودن دسته‌بندی',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      8,
      PermissionsName.productsMarketplaceSend,
      'محصولات',
      'ارسال به مارکت‌پلیس',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      9,
      PermissionsName.productsCategoriesDelete,
      'محصولات',
      'حذف دسته‌بندی',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      12,
      PermissionsName.customersMenu,
      'مشتریان',
      'مشاهده منو',
    ),
    PermissionDefinition(
      13,
      PermissionsName.customersCreate,
      'مشتریان',
      'افزودن',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      14,
      PermissionsName.customersImport,
      'مشتریان',
      'افزودن از اکسل',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      15,
      PermissionsName.customersView,
      'مشتریان',
      'مشاهده',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      16,
      PermissionsName.customersViewAll,
      'مشتریان',
      'مشاهده همه مشتریان',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      17,
      PermissionsName.customersEdit,
      'مشتریان',
      'ویرایش',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      18,
      PermissionsName.customersEditAll,
      'مشتریان',
      'ویرایش همه',
      requiredName: PermissionsName.customersMenu,
    ),
    PermissionDefinition(
      22,
      PermissionsName.invoicesSellCreate,
      'فاکتور فروش',
      'ثبت فاکتور',
    ),
    PermissionDefinition(
      23,
      PermissionsName.invoicesSellCustomersAll,
      'فاکتور فروش',
      'همه مشتریان',
    ),
    PermissionDefinition(
      24,
      PermissionsName.invoicesSellCustomersAssigned,
      'فاکتور فروش',
      'مشتریان منتسب‌شده',
    ),
    PermissionDefinition(
      25,
      PermissionsName.invoicesSellView,
      'فاکتور فروش',
      'مشاهده',
    ),
    PermissionDefinition(
      26,
      PermissionsName.invoicesSellEdit,
      'فاکتور فروش',
      'ویرایش فاکتور',
    ),
    PermissionDefinition(
      27,
      PermissionsName.invoicesSellStatusReady,
      'فاکتور فروش',
      'تغییر به آماده ارسال',
    ),
    PermissionDefinition(
      28,
      PermissionsName.invoicesSellStatusSent,
      'فاکتور فروش',
      'تغییر به ارسال‌شده',
    ),
    PermissionDefinition(
      29,
      PermissionsName.invoicesSellStatusCancelled,
      'فاکتور فروش',
      'تغییر به لغوشده',
    ),
    PermissionDefinition(
      30,
      PermissionsName.invoicesSellStatusReturned,
      'فاکتور فروش',
      'تغییر به مرجوع‌شده',
    ),
    PermissionDefinition(
      31,
      PermissionsName.invoicesSellStatusDelivered,
      'فاکتور فروش',
      'تغییر به تحویل‌شده',
    ),
    PermissionDefinition(
      32,
      PermissionsName.invoicesSellDiscountApply,
      'فاکتور فروش',
      'اعمال تخفیف',
    ),
    PermissionDefinition(
      33,
      PermissionsName.invoicesSellChargesApply,
      'فاکتور فروش',
      'اعمال هزینه اضافی',
    ),
    PermissionDefinition(
      34,
      PermissionsName.invoicesSellPaymentReceive,
      'فاکتور فروش',
      'دریافت وجه',
    ),
    PermissionDefinition(
      35,
      PermissionsName.invoicesSellPaymentOnline,
      'فاکتور فروش',
      'پرداخت آنلاین',
    ),
    PermissionDefinition(
      36,
      PermissionsName.invoicesSellChequeReceive,
      'فاکتور فروش',
      'دریافت چک',
    ),
    PermissionDefinition(
      37,
      PermissionsName.invoicesSellViewAll,
      'فاکتور فروش',
      'مشاهده فاکتور همه',
    ),
    PermissionDefinition(
      38,
      PermissionsName.invoicesSellEditAll,
      'فاکتور فروش',
      'ویرایش فاکتور همه',
    ),
    PermissionDefinition(
      42,
      PermissionsName.invoicesPreCreate,
      'پیش‌فاکتور',
      'ثبت پیش‌فاکتور',
    ),
    PermissionDefinition(
      43,
      PermissionsName.invoicesPreView,
      'پیش‌فاکتور',
      'مشاهده',
    ),
    PermissionDefinition(
      44,
      PermissionsName.invoicesPreEdit,
      'پیش‌فاکتور',
      'ویرایش',
    ),
    PermissionDefinition(
      45,
      PermissionsName.invoicesPreConvert,
      'پیش‌فاکتور',
      'تبدیل به فاکتور',
    ),
    PermissionDefinition(
      46,
      PermissionsName.invoicesPreViewAll,
      'پیش‌فاکتور',
      'مشاهده همه',
    ),
    PermissionDefinition(
      47,
      PermissionsName.invoicesPreEditAll,
      'پیش‌فاکتور',
      'ویرایش همه',
    ),
    PermissionDefinition(
      48,
      PermissionsName.invoicesPreConvertAll,
      'پیش‌فاکتور',
      'تبدیل به فاکتور همه',
    ),
    PermissionDefinition(
      52,
      PermissionsName.suppliersMenu,
      'تأمین‌کنندگان',
      'مشاهده منو',
    ),
    PermissionDefinition(
      53,
      PermissionsName.suppliersCreate,
      'تأمین‌کنندگان',
      'افزودن',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      54,
      PermissionsName.suppliersImport,
      'تأمین‌کنندگان',
      'افزودن از اکسل',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      55,
      PermissionsName.suppliersView,
      'تأمین‌کنندگان',
      'مشاهده',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      56,
      PermissionsName.suppliersEdit,
      'تأمین‌کنندگان',
      'ویرایش',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      57,
      PermissionsName.suppliersViewAll,
      'تأمین‌کنندگان',
      'مشاهده همه',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      58,
      PermissionsName.suppliersEditAll,
      'تأمین‌کنندگان',
      'ویرایش همه',
      requiredName: PermissionsName.suppliersMenu,
    ),
    PermissionDefinition(
      61,
      PermissionsName.invoicesBuyCreate,
      'فاکتور خرید',
      'ثبت فاکتور',
    ),
    PermissionDefinition(
      63,
      PermissionsName.invoicesBuyView,
      'فاکتور خرید',
      'مشاهده',
    ),
    PermissionDefinition(
      64,
      PermissionsName.invoicesBuyEdit,
      'فاکتور خرید',
      'ویرایش فاکتور',
    ),
    PermissionDefinition(
      65,
      PermissionsName.invoicesBuyDelete,
      'فاکتور خرید',
      'حذف فاکتور',
    ),
    PermissionDefinition(
      66,
      PermissionsName.invoicesBuyPaymentPay,
      'فاکتور خرید',
      'پرداخت وجه',
    ),
    PermissionDefinition(
      67,
      PermissionsName.invoicesBuyChequePay,
      'فاکتور خرید',
      'پرداخت چک',
    ),
    PermissionDefinition(
      68,
      PermissionsName.invoicesBuyViewAll,
      'فاکتور خرید',
      'مشاهده همه',
    ),
    PermissionDefinition(
      69,
      PermissionsName.invoicesBuyEditAll,
      'فاکتور خرید',
      'ویرایش همه',
    ),
    PermissionDefinition(
      70,
      PermissionsName.invoicesBuyDeleteAll,
      'فاکتور خرید',
      'حذف همه',
    ),
    PermissionDefinition(
      74,
      PermissionsName.servicersMenu,
      'سرویس‌دهندگان',
      'مشاهده منو',
    ),
    PermissionDefinition(
      75,
      PermissionsName.servicersCreate,
      'سرویس‌دهندگان',
      'افزودن',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(
      76,
      PermissionsName.servicersImport,
      'سرویس‌دهندگان',
      'افزودن از اکسل',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(
      77,
      PermissionsName.servicersView,
      'سرویس‌دهندگان',
      'مشاهده',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(
      78,
      PermissionsName.servicersEdit,
      'سرویس‌دهندگان',
      'ویرایش',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(
      79,
      PermissionsName.servicersViewAll,
      'سرویس‌دهندگان',
      'مشاهده همه',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(
      80,
      PermissionsName.servicersEditAll,
      'سرویس‌دهندگان',
      'ویرایش همه',
      requiredName: PermissionsName.servicersMenu,
    ),
    PermissionDefinition(84, PermissionsName.costsCreate, 'هزینه‌ها', 'ثبت'),
    PermissionDefinition(85, PermissionsName.costsView, 'هزینه‌ها', 'مشاهده'),
    PermissionDefinition(86, PermissionsName.costsEdit, 'هزینه‌ها', 'ویرایش'),
    PermissionDefinition(
      87,
      PermissionsName.costsCategoriesCreate,
      'هزینه‌ها',
      'دسته‌بندی جدید',
    ),
    PermissionDefinition(
      88,
      PermissionsName.costsPaymentPay,
      'هزینه‌ها',
      'پرداخت وجه',
    ),
    PermissionDefinition(
      89,
      PermissionsName.costsChequePay,
      'هزینه‌ها',
      'پرداخت چک',
    ),
    PermissionDefinition(
      90,
      PermissionsName.costsShippingView,
      'هزینه‌ها',
      'مشاهده هزینه ارسال',
    ),
    PermissionDefinition(
      91,
      PermissionsName.costsViewAll,
      'هزینه‌ها',
      'مشاهده همه',
    ),
    PermissionDefinition(
      92,
      PermissionsName.costsEditAll,
      'هزینه‌ها',
      'ویرایش همه',
    ),
    PermissionDefinition(
      93,
      PermissionsName.costsShippingViewAll,
      'هزینه‌ها',
      'مشاهده هزینه ارسال همه',
    ),
    PermissionDefinition(94, PermissionsName.costsDelete, 'هزینه‌ها', 'حذف'),
    PermissionDefinition(
      95,
      PermissionsName.costsDeleteAll,
      'هزینه‌ها',
      'حذف همه',
    ),
    PermissionDefinition(
      97,
      PermissionsName.chequesMenu,
      'چک‌ها',
      'مشاهده منو',
    ),
    PermissionDefinition(
      98,
      PermissionsName.chequesView,
      'چک‌ها',
      'مشاهده',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      99,
      PermissionsName.chequesEdit,
      'چک‌ها',
      'ویرایش',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      100,
      PermissionsName.chequesClear,
      'چک‌ها',
      'پاس',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      101,
      PermissionsName.chequesDelete,
      'چک‌ها',
      'حذف',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      102,
      PermissionsName.chequesViewAll,
      'چک‌ها',
      'مشاهده همه',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      103,
      PermissionsName.chequesEditAll,
      'چک‌ها',
      'ویرایش همه',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      104,
      PermissionsName.chequesClearAll,
      'چک‌ها',
      'پاس همه',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      105,
      PermissionsName.chequesDeleteAll,
      'چک‌ها',
      'حذف همه',
      requiredName: PermissionsName.chequesMenu,
    ),
    PermissionDefinition(
      109,
      PermissionsName.warehousesMenu,
      'انبارها',
      'مشاهده منو',
    ),
    PermissionDefinition(
      110,
      PermissionsName.warehousesView,
      'انبارها',
      'مشاهده',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      111,
      PermissionsName.warehousesCreate,
      'انبارها',
      'افزودن',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      112,
      PermissionsName.warehousesEdit,
      'انبارها',
      'ویرایش',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      113,
      PermissionsName.warehousesDelete,
      'انبارها',
      'حذف',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      114,
      PermissionsName.warehousesStocktake,
      'انبارها',
      'انبارگردانی',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      115,
      PermissionsName.warehousesTransfer,
      'انبارها',
      'جابجایی بین انبارها',
      requiredName: PermissionsName.warehousesMenu,
    ),
    PermissionDefinition(
      119,
      PermissionsName.distributionMenu,
      'توزیع',
      'مشاهده منو',
    ),
    PermissionDefinition(
      120,
      PermissionsName.distributionRoute,
      'توزیع',
      'مسیریابی',
      requiredName: PermissionsName.distributionMenu,
    ),
    PermissionDefinition(
      125,
      PermissionsName.staffMenu,
      'میک‌یار',
      'مشاهده منو',
    ),
    PermissionDefinition(
      126,
      PermissionsName.staffCreate,
      'میک‌یار',
      'افزودن',
      requiredName: PermissionsName.staffMenu,
    ),
    PermissionDefinition(
      127,
      PermissionsName.staffView,
      'میک‌یار',
      'مشاهده',
      requiredName: PermissionsName.staffMenu,
    ),
    PermissionDefinition(
      128,
      PermissionsName.staffEdit,
      'میک‌یار',
      'ویرایش مشخصات',
      requiredName: PermissionsName.staffMenu,
    ),
    PermissionDefinition(
      129,
      PermissionsName.staffPermissionsEdit,
      'میک‌یار',
      'ویرایش دسترسی',
      requiredName: PermissionsName.staffMenu,
    ),
    PermissionDefinition(
      130,
      PermissionsName.staffPerformanceView,
      'میک‌یار',
      'مشاهده عملکرد',
      requiredName: PermissionsName.staffMenu,
    ),
    PermissionDefinition(
      134,
      PermissionsName.rolesView,
      'سطوح دسترسی',
      'مشاهده',
    ),
    PermissionDefinition(
      135,
      PermissionsName.rolesEdit,
      'سطوح دسترسی',
      'ویرایش',
    ),
    PermissionDefinition(
      139,
      PermissionsName.reportsProfitView,
      'گزارشات',
      'سود و زیان',
    ),
    PermissionDefinition(
      140,
      PermissionsName.reportsQuantityView,
      'گزارشات',
      'تعدادی',
    ),
    PermissionDefinition(151, PermissionsName.crmView, 'CRM', 'مشاهده'),
    PermissionDefinition(152, PermissionsName.crmCreate, 'CRM', 'ارتباط جدید'),
    PermissionDefinition(153, PermissionsName.crmViewAll, 'CRM', 'مشاهده همه'),
    PermissionDefinition(154, PermissionsName.crmEdit, 'CRM', 'ویرایش'),
    PermissionDefinition(155, PermissionsName.crmEditAll, 'CRM', 'ویرایش همه'),
    PermissionDefinition(
      168,
      PermissionsName.smsMenu,
      'اطلاع‌رسانی',
      'مشاهده منو',
    ),
    PermissionDefinition(
      169,
      PermissionsName.smsPatternsView,
      'اطلاع‌رسانی',
      'مشاهده پترن‌ها',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      170,
      PermissionsName.smsPatternsCreate,
      'اطلاع‌رسانی',
      'افزودن پترن',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      171,
      PermissionsName.smsPatternsEdit,
      'اطلاع‌رسانی',
      'ویرایش',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      172,
      PermissionsName.smsPatternsViewAll,
      'اطلاع‌رسانی',
      'مشاهده همه',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      173,
      PermissionsName.smsPatternsEditAll,
      'اطلاع‌رسانی',
      'ویرایش همه',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      174,
      PermissionsName.smsHistoryView,
      'اطلاع‌رسانی',
      'تاریخچه ارسال',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      175,
      PermissionsName.smsBalanceView,
      'اطلاع‌رسانی',
      'مشاهده شارژ',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      176,
      PermissionsName.smsBalanceTopup,
      'اطلاع‌رسانی',
      'شارژ مجدد',
      requiredName: PermissionsName.smsMenu,
    ),
    PermissionDefinition(
      181,
      PermissionsName.accountsMenu,
      'سایر',
      'صورت‌حساب',
    ),
    PermissionDefinition(
      191,
      PermissionsName.productsPropertiesCreate,
      'ویژگی محصولات',
      'افزودن ویژگی',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      192,
      PermissionsName.productsPropertiesEdit,
      'ویژگی محصولات',
      'ویرایش ویژگی',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      193,
      PermissionsName.productsPropertiesDelete,
      'ویژگی محصولات',
      'حذف ویژگی',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      194,
      PermissionsName.productsPropertiesEditAll,
      'ویژگی محصولات',
      'ویرایش ویژگی همه',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      195,
      PermissionsName.productsPropertiesDeleteAll,
      'ویژگی محصولات',
      'حذف ویژگی همه',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      196,
      PermissionsName.productsPropertiesAssign,
      'ویژگی محصولات',
      'اختصاص ویژگی به محصول',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      201,
      PermissionsName.productsPricesCreate,
      'قیمت‌گذاری محصولات',
      'افزودن قیمت',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      202,
      PermissionsName.productsPricesEdit,
      'قیمت‌گذاری محصولات',
      'ویرایش قیمت',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      203,
      PermissionsName.productsPricesDelete,
      'قیمت‌گذاری محصولات',
      'حذف قیمت',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      204,
      PermissionsName.productsPricesEditAll,
      'قیمت‌گذاری محصولات',
      'ویرایش قیمت همه',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      205,
      PermissionsName.productsPricesDeleteAll,
      'قیمت‌گذاری محصولات',
      'حذف قیمت همه',
      requiredName: PermissionsName.productsMenu,
    ),
    PermissionDefinition(
      206,
      PermissionsName.productsPricesDefaultSet,
      'قیمت‌گذاری محصولات',
      'تغییر قیمت پیش‌فرض',
      requiredName: PermissionsName.productsMenu,
    ),
  ];
  static final byName = {for (final p in definitions) p.name: p};
  static final byLegacyIndex = {for (final p in definitions) p.legacyIndex: p};

  /// Accepts old bit strings and new JSON lists of named permissions.
  /// Malformed legacy values deny access rather than partially granting it.
  static Set<String> decode(String? stored) {
    final value = stored?.trim() ?? '';
    if (value.isEmpty) return {};
    if (value.startsWith('[')) {
      try {
        final names = jsonDecode(value);
        if (names is! List || names.any((n) => n is! String)) return {};
        return names.cast<String>().where(byName.containsKey).toSet();
      } on FormatException {
        return {};
      }
    }
    if (!RegExp(r'^[01]+$').hasMatch(value)) return {};
    return {
      for (final p in definitions)
        if (p.legacyIndex < value.length && value[p.legacyIndex] == '1') p.name,
    };
  }

  static String encodeNames(Iterable<String> names) {
    final result = names.where(byName.containsKey).toSet().toList()..sort();
    return jsonEncode(result);
  }

  /// API compatibility: preserve reserved positions from existing server data.
  static String encodeLegacy(Iterable<String> names, {String? original}) {
    final valid = original != null && RegExp(r'^[01]+$').hasMatch(original);
    final length = valid && original.length > legacyCount
        ? original.length
        : legacyCount;
    final bits = List<String>.filled(length, '0');
    if (valid) {
      for (var i = 0; i < original.length; i++) bits[i] = original[i];
    }
    bits[0] = '1'; // Legacy protocol marker, never an access grant.
    final selected = names.toSet();
    for (final p in definitions)
      bits[p.legacyIndex] = selected.contains(p.name) ? '1' : '0';
    return bits.join();
  }

  /// Used only by the role editor; loading existing grants never adds rights.
  static Set<String> select(
    Iterable<String> selected,
    String name,
    bool enabled,
  ) {
    final result = selected.where(byName.containsKey).toSet();
    if (!byName.containsKey(name)) return result;
    if (enabled) {
      String? next = name;
      final visited = <String>{};
      while (next != null && visited.add(next)) {
        result.add(next);
        next = byName[next]?.requiredName;
      }
    } else {
      final revoked = <String>{name};
      result.remove(name);
      bool removed;
      do {
        final dependent = result
            .where((key) => revoked.contains(byName[key]?.requiredName))
            .toList();
        removed = dependent.isNotEmpty;
        revoked.addAll(dependent);
        result.removeAll(dependent);
      } while (removed);
    }
    return result;
  }
}
