import 'package:hive/hive.dart';

import '../models/models.dart';

late Box<SettingsData> settingsData; //
late Box<LocalSetting> localSetting; //
late Box<ProfileDB> profile; //
late Box<PersonDB> person; //
late Box<PartnerTransactionDB> partnerTransaction; //
late Box<CategoryDB> category; //
late Box<ProductDB> product; //
late Box<WarehouseNameDB> warehouseName; //
late Box<WarehouseHistoryDB> warehouseHistory; //
late Box<WarehouseDB> warehouse; //
late Box<FactorDB> factor; //
late Box<InvoiceDB> invoice; //
late Box<EditInvoiceHistoryDB> editInvoiceHistory; //
late Box<CommissionDB> commission; //
late Box<CostCategoryDB> costCategory; //
late Box<CostDB> cost; //
late Box<JWT> jwt; //
late Box<DataQueue> dataQueue; //
late Box<BillDB> bill; //
late Box<ChequeDB> cheque; //
late Box<FinancialPeriod> financialPeriod; //--
late Box<FCM> fcm; //
late Box<MSG> msg;
late Box<PatternDB> pattern; //
late Box<SMS> sms; //
late Box<TemporaryProduct> temporaryProduct; //
late Box<ProductPropertyDB> productProperty; //
late Box<ProductProDB> productPro; //
late Box<ProductPriceDB> productPrice; //
late Box<ProductDraftDB>
    productDraft; // برای ذخیره محصولات موقت در فرآیند افزودن گروهی
late Box<DataToServer> dataToServer; //
late Box<ConnectionDB> connection; //

late Box<MiKYarDB> mikyar; //
late Box<MiKYarPermissionDB> mikyarPermission; //
late Box<MiKYarPermissionExtDB> mikyarPermissionExt; //

late Box<BranchDB> branch; //
late Box<BranchAccessDB> branchAccess; //
// ticket
// campaign
