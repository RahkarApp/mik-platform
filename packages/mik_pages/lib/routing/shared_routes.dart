import 'package:mik_pages/customers/crm/remote_screen.dart'
    as customersCrmRemoteScreen;
import 'package:mik_pages/customers/customer_form.dart'
    as customersCustomerForm;
import 'package:mik_pages/bill/party_account.dart' as billPartyAccount;
import 'package:mik_pages/loans/management_form.dart' as loansManagementForm;
import 'package:mik_pages/loans/forms.dart' as loansForms;
import 'package:mik_pages/loans/screen.dart' as loansScreen;
import 'package:mik_pages/bill/party_payment.dart' as billPartyPayment;
import 'package:mik_pages/cheque/remote_screen.dart' as chequeRemoteScreen;
import 'package:mik_pages/product/bulk/screen.dart' as productBulkScreen;
import 'package:mik_pages/chatBase/onboarding/step2chat.dart'
    as chatBaseOnboardingStep2chat;
import 'package:mik_pages/cost/expense_payment_screen.dart'
    as costExpensePaymentScreen;
import 'package:mik_pages/cost/remote_screen.dart' as costRemoteScreen;
import 'package:mik_pages/persons/supplier/server_screen.dart'
    as personsSupplierServerScreen;
import 'package:mik_pages/product/brand/screen.dart' as productBrandScreen;
import 'package:mik_pages/product/edit/screen.dart' as productEditScreen;
import 'package:mik_pages/product/warehouse/stock_screen.dart'
    as productWarehouseStockScreen;
import 'package:mik_pages/product/media_screen.dart' as productMediaScreen;
import 'package:mik_pages/product/variant/screen.dart' as productVariantScreen;
import 'package:mik_pages/product/price/screen.dart' as productPriceScreen;
import 'package:mik_pages/product/detail/shop_screen.dart'
    as productDetailShopScreen;
import 'package:mik_pages/chatBase/addProduct/addGroupeChat.dart'
    as chatBaseAddProductAddGroupeChat;
import 'package:mik_pages/product/screen/screen.dart' as productScreenScreen;
import 'package:mik_pages/product/property/form.dart' as productPropertyForm;
import 'package:mik_pages/product/variant/option_screen.dart'
    as productVariantOptionScreen;
import 'package:mik_pages/product/variant/axes_screen.dart'
    as productVariantAxesScreen;
import 'package:mik_pages/product/warehouse/count_screen.dart'
    as productWarehouseCountScreen;
import 'package:mik_pages/persons/partner/movements_screen.dart'
    as personsPartnerMovementsScreen;
import 'package:mik_pages/persons/partner/ownership_screen.dart'
    as personsPartnerOwnershipScreen;
import 'package:mik_pages/branches/screen.dart' as branchesScreen;
import 'package:mik_pages/treasury/screen.dart' as treasuryScreen;
import 'package:mik_pages/assets/payment_screen.dart' as assetsPaymentScreen;
import 'package:mik_pages/assets/disposal_form.dart' as assetsDisposalForm;
import 'package:mik_pages/assets/repair_form.dart' as assetsRepairForm;
import 'package:mik_pages/assets/edit_form.dart' as assetsEditForm;
import 'package:mik_pages/assets/lifecycle_form.dart' as assetsLifecycleForm;
import 'package:mik_pages/assets/screen.dart' as assetsScreen;
import 'package:mik_pages/personnel/screen.dart' as personnelScreen;
import 'package:mik_pages/reports/financial_screen.dart'
    as reportsFinancialScreen;
import 'package:mik_pages/invoice/change_product_picker.dart'
    as invoiceChangeProductPicker;
import 'package:mik_utils/public/POS/page.dart' as publicPOSPage;
import 'package:mik_pages/invoice/add/purchase_products.dart'
    as invoiceAddPurchaseProducts;
import 'package:mik_pages/invoice/add/sale_products.dart'
    as invoiceAddSaleProducts;
import 'package:mik_pages/invoice/add/components/selectproduct.dart'
    as invoiceAddComponentsSelectproduct;
import 'package:mik_pages/invoice/read_screen.dart' as invoiceReadScreen;
import 'package:mik_pages/invoice/payment_screen.dart' as invoicePaymentScreen;
import 'package:mik_pages/invoice/change_screen.dart' as invoiceChangeScreen;
import 'package:mik_pages/invoice/payment_correction_screen.dart'
    as invoicePaymentCorrectionScreen;
import 'package:mik_pages/settings/business_settings_screen.dart'
    as settingsBusinessSettingsScreen;
import 'package:mik_pages/sms/screen.dart' as smsScreen;
import 'package:mik_pages/sms/funding_screen.dart' as smsFundingScreen;
import 'package:mik_pages/assets/create_form.dart' as assetsCreateForm;
import 'package:mik_pages/reports/quantity_unavailable.dart'
    as reportsQuantityUnavailable;
import 'package:mik_data/models/models.dart';
import 'package:mik_data/source/remote/models/business_session.dart';
import 'package:mik_router/mik_router.dart';

import '../bill/add/screen.dart';
import '../bill/screen.dart';
import '../cheque/add/screen.dart';
import '../cheque/screen.dart';
import '../cost/add/screen.dart';
import '../cost/detail/screen.dart';
import '../cost/screen.dart';
import '../customers/crm/screen/connections/add.dart';
import '../customers/crm/screen/connections/screen.dart';
import '../invoice/add/screen.dart';
import '../invoice/detail/screen.dart';
import '../invoice/screen.dart';
import '../login/screen.dart';
import '../persons/add/screen.dart';
import '../persons/partner/details.dart';
import '../persons/screen.dart';
import '../persons/servicer/details.dart';
import '../persons/supplier/details.dart';
import '../product/screen/screen.dart';
import '../product/detail/screen.dart';
import '../product/add/screen.dart';
import '../reports/reports.dart';

/// Shared pages use models and boxes from mik_data.
/// Hosts register dashboards, startup, locks, permissions, and private pages.
abstract final class SharedRoutes {
  static Map<String, MikPageBuilder> get namedPages => {
    RoutesName.CUSTOMER_CRM: customersCrmRemoteScreen.buildCustomerCrmRoute,
    RoutesName.CRM_FORM: customersCrmRemoteScreen.buildCrmFormRoute,
    RoutesName.CUSTOMER_FORM: customersCustomerForm.buildCustomerFormRoute,
    RoutesName.PARTY_ACCOUNT: billPartyAccount.buildPartyAccountRoute,
    RoutesName.LOAN_MANAGEMENT_FORM:
        loansManagementForm.buildLoanManagementFormRoute,
    RoutesName.LOAN_FORM: loansForms.buildLoanFormRoute,
    RoutesName.LOANS: loansScreen.buildLoansRoute,
    RoutesName.PARTY_PAYMENT: billPartyPayment.buildPartyPaymentRoute,
    RoutesName.CHEQUE_FORM: chequeRemoteScreen.buildChequeFormRoute,
    RoutesName.PRODUCT_BULK: productBulkScreen.buildProductBulkRoute,
    RoutesName.LEGACY_ONBOARDING_STEP2:
        chatBaseOnboardingStep2chat.buildStep2ChatRoute,
    RoutesName.EXPENSE_PAYMENT_ACTION:
        costExpensePaymentScreen.buildExpensePaymentActionRoute,
    RoutesName.EXPENSE_CATEGORY_FORM:
        costRemoteScreen.buildExpenseCategoryFormRoute,
    RoutesName.REMOTE_EXPENSE_FORM:
        costRemoteScreen.buildRemoteExpenseFormRoute,
    RoutesName.EXPENSE_DETAIL: costRemoteScreen.buildExpenseDetailRoute,
    RoutesName.EXPENSE_PAYMENT:
        costExpensePaymentScreen.buildExpensePaymentRoute,
    RoutesName.SUPPLIERS: personsSupplierServerScreen.buildSuppliersRoute,
    RoutesName.PRODUCT_BRAND_FORM:
        productBrandScreen.buildProductBrandFormRoute,
    RoutesName.PRODUCT_EDIT: productEditScreen.buildProductEditRoute,
    RoutesName.WAREHOUSE_STOCK:
        productWarehouseStockScreen.buildWarehouseStockRoute,
    RoutesName.PRODUCT_MEDIA: productMediaScreen.buildProductMediaRoute,
    RoutesName.PRODUCT_VARIANTS: productVariantScreen.buildProductVariantsRoute,
    RoutesName.PRODUCT_PRICES: productPriceScreen.buildProductPricesRoute,
    RoutesName.PRODUCT_SHOP: productDetailShopScreen.buildProductShopRoute,
    RoutesName.PRODUCT_GROUP_ADD:
        chatBaseAddProductAddGroupeChat.buildProductGroupAddRoute,
    RoutesName.CAT_MANAGE: productScreenScreen.buildCatManageRoute,
    RoutesName.PRODUCT_ATTRIBUTE_FORM:
        productPropertyForm.buildProductAttributeFormRoute,
    RoutesName.PRODUCT_OPTION:
        productVariantOptionScreen.buildProductOptionRoute,
    RoutesName.PRODUCT_AXES: productVariantAxesScreen.buildProductAxesRoute,
    RoutesName.STOCK_ITEM: productWarehouseStockScreen.buildStockItemRoute,
    RoutesName.COUNT_START: productWarehouseCountScreen.buildCountStartRoute,
    RoutesName.COUNT_EDIT: productWarehouseCountScreen.buildCountEditRoute,
    RoutesName.WAREHOUSE_COUNT:
        productWarehouseCountScreen.buildWarehouseCountRoute,
    RoutesName.PARTNER_MOVEMENT_FORM:
        personsPartnerMovementsScreen.buildPartnerMovementFormRoute,
    RoutesName.SUPPLIER_FORM:
        personsSupplierServerScreen.buildSupplierFormRoute,
    RoutesName.PARTNER_MOVEMENTS:
        personsPartnerMovementsScreen.buildPartnerMovementsRoute,
    RoutesName.PARTNER_OWNERSHIP:
        personsPartnerOwnershipScreen.buildPartnerOwnershipRoute,
    RoutesName.BRANCH_FORM: branchesScreen.buildBranchFormRoute,
    RoutesName.TREASURY: treasuryScreen.buildTreasuryRoute,
    RoutesName.TREASURY_FORM: treasuryScreen.buildTreasuryFormRoute,
    RoutesName.ASSET_PAYMENT_ACTION:
        assetsPaymentScreen.buildAssetPaymentActionRoute,
    RoutesName.ASSET_DISPOSAL_FORM:
        assetsDisposalForm.buildAssetDisposalFormRoute,
    RoutesName.ASSET_REPAIR_FORM: assetsRepairForm.buildAssetRepairFormRoute,
    RoutesName.ASSET_EDIT_FORM: assetsEditForm.buildAssetEditFormRoute,
    RoutesName.ASSET_LIFECYCLE_FORM:
        assetsLifecycleForm.buildAssetLifecycleFormRoute,
    RoutesName.ASSET_PAYMENT: assetsPaymentScreen.buildAssetPaymentRoute,
    RoutesName.FIXED_ASSETS: assetsScreen.buildFixedAssetsRoute,
    RoutesName.PERSONNEL_FORM: personnelScreen.buildPersonnelFormRoute,
    RoutesName.PERSONNEL_ACCESS: personnelScreen.buildPersonnelAccessRoute,
    RoutesName.FINANCIAL_REPORT:
        reportsFinancialScreen.buildFinancialReportRoute,
    RoutesName.INVOICE_CHANGE_PRODUCT_PICKER:
        invoiceChangeProductPicker.buildInvoiceChangeProductPickerRoute,
    RoutesName.INVOICE_PRINT: publicPOSPage.buildCreateWidgetPringRoute,
    RoutesName.PURCHASE_PRODUCTS:
        invoiceAddPurchaseProducts.buildPurchaseProductsRoute,
    RoutesName.SALE_PRODUCT_PICKER:
        invoiceAddSaleProducts.buildSaleProductPickerRoute,
    RoutesName.SELECT_PRODUCT_FOR_INVOICE:
        invoiceAddComponentsSelectproduct.buildSelectProductForInvoiceRoute,
    RoutesName.REMOTE_INVOICE_DETAIL:
        invoiceReadScreen.buildRemoteInvoiceDetailRoute,
    RoutesName.INVOICE_PAYMENT: invoicePaymentScreen.buildInvoicePaymentRoute,
    RoutesName.INVOICE_CHANGE: invoiceChangeScreen.buildInvoiceChangeRoute,
    RoutesName.INVOICE_PAYMENT_CORRECTION:
        invoicePaymentCorrectionScreen.buildInvoicePaymentCorrectionRoute,
    RoutesName.REMOTE_CHEQUE: chequeRemoteScreen.buildRemoteChequeRoute,
    RoutesName.BUSINESS_SETTINGS:
        settingsBusinessSettingsScreen.buildBusinessSettingsRoute,
    RoutesName.SMS_TEMPLATE: smsScreen.buildSmsTemplateRoute,
    RoutesName.SMS_FUNDING: smsFundingScreen.buildSmsFundingRoute,
    RoutesName.BUSINESS_SMS: smsScreen.buildBusinessSmsRoute,
    RoutesName.ASSET_CREATE_FORM: assetsCreateForm.buildAssetCreateFormRoute,
    RoutesName.WAREHOUSE_MANAGEMENT:
        reportsQuantityUnavailable.buildWarehouseManagementRoute,
  };

  static Map<String, MikPageBuilder> pages({bool includeMikLogin = false}) => {
    ...namedPages,
    if (includeMikLogin) ...{
      RoutesName.LOGIN: (_) => const LoginScreen(),
      RoutesName.REGISTER: (_) => const RegisterScreen(),
      RoutesName.GETDATA: (_) => const GetDataScreen(),
      RoutesName.ONBOARDING: (_) => OnboardingScreen(),
      RoutesName.WELCOME: (settings) => Welcome(
        session: settings.arguments is BusinessSession
            ? settings.arguments as BusinessSession
            : null,
      ),
    },
    RoutesName.PRODUCTS: (_) => ProductDashboardScreen(),
    RoutesName.PRODUCTADD: (settings) =>
        PimProductAddScreen.fromArguments(settings.arguments, appId: 'mik'),
    RoutesName.PRODUCTDETAILS: (settings) =>
        ProductDetailScreen.fromArguments(settings.arguments, appId: 'mik'),
    // Deleted product pages stay unregistered until their replacement is ready.
    RoutesName.INVOICES: (_) => InvoiceScreen(),
    RoutesName.INVOICEADD: (s) => InvoiceAddScreen(
      type: RouteArguments(s).optional<String>('type'),
      item: RouteArguments(s).optional<InvoiceDB>('item'),
      puid: RouteArguments(s).optional<String>('personUID'),
    ),
    RoutesName.INVOICEDETAIL: (s) => InvoiceDetScreen(
      item: RouteArguments(s).required<InvoiceDB>('item'),
      type: RouteArguments(s).optional<String>('type'),
    ),
    RoutesName.BILL: (_) => BillScreen(),
    RoutesName.BILLADD: (s) => BillAddScreen(
      billID: RouteArguments(s).optional<int>('billID'),
      billUID: RouteArguments(s).optional<String>('billUID'),
      mode: RouteArguments(s).required<String>('mode'),
    ),
    RoutesName.CHEQUE: (_) => ChequeScreen(),
    RoutesName.CHEQUEADD: (_) => const ChequeAddScreen(),
    RoutesName.COST: (_) => CostScreen(),
    RoutesName.COSTADD: (s) => CostAddScreen(
      item: RouteArguments(s).optional<CostDB>('item'),
      puid: RouteArguments(s).optional<String>('personUID'),
      pid: RouteArguments(s).optional<int>('personID'),
    ),
    RoutesName.COSTDETAIL: (s) => CostDetailScreen(
      item: RouteArguments(s).required<CostDB>('item'),
      type: RouteArguments(s).optional<String>('type') ?? '',
    ),
    RoutesName.PERSONEADD: (s) => PersonAddScreen(
      title: RouteArguments(s).optional<String>('title') ?? 'مشتری جدید',
      item: RouteArguments(s).optional<PersonDB>('item'),
      mobile: RouteArguments(s).optional<String>('mobile'),
    ),
    RoutesName.PARTNER: (_) => PersonScreen('partner'),
    RoutesName.SUPPLIER: (_) => PersonScreen('supplier'),
    RoutesName.SERVICER: (_) => PersonScreen('servicer'),
    RoutesName.PARTNERDETAIL: (s) =>
        PertnerDetailsScreen(RouteArguments(s).required<PersonDB>('item')),
    RoutesName.SUPPLIERDETAIL: (s) =>
        SupplierDetailsScreen(RouteArguments(s).required<PersonDB>('item')),
    RoutesName.SERVICERDETAIL: (s) =>
        ServicerDetailsScreen(RouteArguments(s).required<PersonDB>('item')),
    RoutesName.CRMCONNECTIONS: (_) => const CRMConnections(),
    RoutesName.CRMCONNETCIONADD: (s) => CRMConnectionsAdd(
      puid: RouteArguments(s).optional<String>('puid'),
      pname: RouteArguments(s).optional<String>('pname'),
      parentUID: RouteArguments(s).optional<String>('parentUID'),
    ),
    RoutesName.REPORTS: (_) => const ReportsTabDashboard(),
    RoutesName.REPORTSPROFIT: (_) => ReportProfit(),
    RoutesName.REPORTSPRODUCTCOUNT: (_) => ReportProductsCount(),
    RoutesName.REPORTSPRODUCTCOUNTDETAIL: (s) => ReportProductsCountDetails(
      productUID: RouteArguments(s).required<String>('productUID'),
    ),
  };
}
