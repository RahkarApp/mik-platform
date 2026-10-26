import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:mik_data/source/remote/api.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_variables/variable.dart';

import '../../models/models.dart';
import '../../utils/saveHelper.dart';
import '../../utils/variable.dart';

class DB {
  static register() async {
    // registerAdapter = true;
    if (!kIsWeb) {
      Hive.init(dir!.path);
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive
        ..registerAdapter(ProfileDBAdapter())
        ..registerAdapter(JWTAdapter())
        ..registerAdapter(PersonDBAdapter())
        ..registerAdapter(DataQueueAdapter())
        ..registerAdapter(DataToServerAdapter())
        ..registerAdapter(PartnerTransactionDBAdapter())
        ..registerAdapter(ProductDBAdapter())
        ..registerAdapter(WarehouseNameDBAdapter())
        ..registerAdapter(WarehouseDBAdapter())
        ..registerAdapter(WarehouseHistoryDBAdapter())
        ..registerAdapter(CategoryDBAdapter())
        ..registerAdapter(FactorDBAdapter())
        ..registerAdapter(InvoiceDBAdapter())
        ..registerAdapter(EditInvoiceHistoryDBAdapter())
        ..registerAdapter(CommissionDBAdapter())
        ..registerAdapter(CostCategoryDBAdapter())
        ..registerAdapter(CostDBAdapter())
        ..registerAdapter(SettingsDataAdapter())
        ..registerAdapter(SendSmsSettingAdapter())
        ..registerAdapter(BillDBAdapter())
        ..registerAdapter(FinancialPeriodAdapter())
        ..registerAdapter(LocalSettingAdapter())
        ..registerAdapter(FCMAdapter())
        ..registerAdapter(MSGAdapter())
        ..registerAdapter(PollTypeAdapter())
        ..registerAdapter(PatternDBAdapter())
        ..registerAdapter(SMSAdapter())
        ..registerAdapter(SmsPatternValueAdapter())
        ..registerAdapter(ProductPropertyDBAdapter())
        ..registerAdapter(ProductProDBAdapter())
        ..registerAdapter(TemporaryProductAdapter())
        ..registerAdapter(ChequeDBAdapter())
        ..registerAdapter(ConnectionDBAdapter())
        ..registerAdapter(MiKYarDBAdapter())
        ..registerAdapter(MiKYarPermissionDBAdapter())
        ..registerAdapter(MiKYarPermissionExtDBAdapter())
        ..registerAdapter(BranchDBAdapter())
        ..registerAdapter(BranchAccessDBAdapter())
        ..registerAdapter(ProductPriceDBAdapter())
        ..registerAdapter(ProductDraftDBAdapter())
        ..registerAdapter(OnboardingDraftDBAdapter());
    }
  }

  static String? namespace;
  static String boxName(String name) =>
      namespace == null ? name : '$namespace.$name';
  static String businessNamespace({
    required String origin,
    required String identityId,
    required int businessId,
  }) {
    final owner = utf8
        .encode('$origin|$identityId')
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'v1.$owner.$businessId';
  }

  static Future<bool> hasBusinessCache({
    required String origin,
    required String identityId,
    required int businessId,
  }) async {
    if (!Hive.isAdapterRegistered(1)) return false;
    final name =
        '${businessNamespace(origin: origin, identityId: identityId, businessId: businessId)}.prf';
    if (!await Hive.boxExists(name)) return false;
    final cached = Hive.isBoxOpen(name)
        ? Hive.box<ProfileDB>(name)
        : await Hive.openBox<ProfileDB>(name);
    return cached.isNotEmpty && cached.getAt(0)!.id == businessId;
  }

  static read({String? namespace}) async {
    DB.namespace = namespace;
    Future<Box<T>> open<T>(String name) => Hive.openBox<T>(boxName(name));
    if (!Hive.isBoxOpen(boxName('prf'))) await register();
    jwt = await open<JWT>('jwt');
    profile = await open<ProfileDB>('prf');
    settingsData = await open<SettingsData>('settings');
    localSetting = await open<LocalSetting>('localSetting');
    temporaryProduct = await open<TemporaryProduct>('temporaryProduct');
    person = await open<PersonDB>('person');
    partnerTransaction = await open<PartnerTransactionDB>('partnerTransaction');
    category = await open<CategoryDB>('category');
    product = await open<ProductDB>('product');
    productPro = await open<ProductProDB>('productPro');
    productPrice = await open<ProductPriceDB>('productPrice');
    productProperty = await open<ProductPropertyDB>('productPreoperty');
    warehouse = await open<WarehouseDB>('warehouse');
    warehouseName = await open<WarehouseNameDB>('warehouseName');
    warehouseHistory = await open<WarehouseHistoryDB>('warehouseHistory');
    factor = await open<FactorDB>('factor');
    invoice = await open<InvoiceDB>('invoice');
    editInvoiceHistory = await open<EditInvoiceHistoryDB>('editInvoiceHistory');
    dataQueue = await open<DataQueue>('dataQueue');
    //"/data/user/0/com.rahkarapp.mik/app_flutter"
    dataToServer = await open<DataToServer>('dataToServer');
    dataQueueFlag.value = dataQueue.isNotEmpty || dataToServer.isNotEmpty;
    dataToServerFlag.value = dataToServer.isNotEmpty;

    commission = await open<CommissionDB>('commission');
    costCategory = await open<CostCategoryDB>('costCategory');
    cost = await open<CostDB>('cost');
    bill = await open<BillDB>('bill');
    cheque = await open<ChequeDB>('cheque');
    financialPeriod = await open<FinancialPeriod>('financialPeriod');
    pattern = await open<PatternDB>('pattern');
    sms = await open<SMS>('sms');

    msg = await open<MSG>('msg');
    msgCount.value = msg.values
        .where((element) => !element.read!)
        .toList()
        .length;
    connection = await open<ConnectionDB>('connection');

    mikyar = await open<MiKYarDB>('mikyar');
    mikyarPermission = await open<MiKYarPermissionDB>('mikyarPermission');
    mikyarPermissionExt = await open<MiKYarPermissionExtDB>(
      'mikyarPermissionExt',
    );

    branch = await open<BranchDB>('branch');
    branchAccess = await open<BranchAccessDB>('branchAccess');
    productDraft = await open<ProductDraftDB>('productDraft');
  }

  static update() async {
    // await mikyarPermission.clear();
    dbUpdate.value = true;
    int wid = ID.newId(warehouseName);
    String defaultWarehouseMainBranch = ID.uidNew(id: wid + 1);
    if (warehouseName.isEmpty) {
      WarehouseNameDB nw = WarehouseNameDB(
        id: wid,
        uid: ID.uidNew(id: wid),
        name: 'مرکزی',
        active: true,
        inserter: 0,
        backup: 'new',
      );
      await SaveHelper.save(nw);
      await Future.delayed(const Duration(milliseconds: 20));

      WarehouseNameDB nw2 = WarehouseNameDB(id: wid + 1, uid: defaultWarehouseMainBranch, name: 'شعبه اصلی', active: true, inserter: 0, backup: 'new');
      await SaveHelper.save(nw2);
    }
    if (warehouse.length < product.length) {
      List pinw = warehouse.values.map((w) {
        return w.puid;
      }).toList();

      dbUpdateLength.value = product.length.toDouble();
      dbUpdateCurrent.value = pinw.length.toDouble();
      int wid = ID.newId(warehouse);
      for (var i = 0; i < product.length; i++) {
        ProductDB p = product.getAt(i)!;
        if (p.type == 'product' && !pinw.contains(p.uid)) {
          WarehouseDB v = WarehouseDB(
            id: wid + i,
            uid: ID.uidNew(id: wid + i),
            wuid: warehouseName.getAt(0)!.uid!,
            puid: p.uid!,
            prouid: '-',
            inventory: p.inventory ?? 0,
            inserter: 0,
            backup: 'new',
          );
          await SaveHelper.save(v);
          await Future.delayed(const Duration(milliseconds: 20));
          dbUpdateCurrent.value++;
        }
      }
    }

    if (branch.isEmpty) {
      BranchDB br = BranchDB(id: 1, uid: ID.uidNew(id: 1), name: 'اصلی', defaultWarehouse: defaultWarehouseMainBranch, inserter: 0, active: true);
      await SaveHelper.save(br);
      await Future.delayed(const Duration(milliseconds: 20));
      BranchAccessDB ba = BranchAccessDB(id: 1, uid: ID.uidNew(id: 1), branchUID: br.uid!, inserter: 0, warehouseUID: [warehouseName.getAt(1)!.uid!]);
      await SaveHelper.save(ba);
    }

    if (mikyarPermission.isEmpty) {
      var pr1 = MiKYarPermissionDB(
        id: 1,
        uid: ID.uidNew(id: 1),
        name: 'مدیر فروشگاه',
        permission:
            '1111111111001111111000111111111111111110001111111000111111100111111111000011111110001111111111110111111111000110001100000000011111100011000000000000000111110000000000001111111110000100000000011111100001111110000',
        backup: 'new',
        inserter: 0,
      );
      var pr2 = MiKYarPermissionDB(
        id: 2,
        uid: ID.uidNew(id: 2),
        name: 'فروشنده/بازاریاب',
        permission:
            '1100000000001101111000111110000010111000001111000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000110100000000000000000000000000100000000000000000000000000000',
        backup: 'new',
        inserter: 0,
      );

      var pr3 = MiKYarPermissionDB(
        id: 3,
        uid: ID.uidNew(id: 3),
        name: 'انباردار',
        permission:
            '1100000000001001100000000001111101000100000000000000000000000000000000000000000000000000000000000000000000000110001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        backup: 'new',
        inserter: 0,
      );
      // var pr4 = MiKYarPermissionDB(
      //     id: 4,
      //     uid: ID.uidNew(id: 4),
      //     name: 'موزع',
      //     permission:
      //         '11000000000010001000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000',
      //     backup: 'new',
      //     inserter: 0);
      await SaveHelper.save(pr1);
      await Future.delayed(const Duration(milliseconds: 20));
      await SaveHelper.save(pr2);
      await Future.delayed(const Duration(milliseconds: 20));
      await SaveHelper.save(pr3);
      await Future.delayed(const Duration(milliseconds: 20));
      // await SaveHelper.save(pr4);
    }
    if (category.isEmpty) {
      final cList = await API.getCat();
      var catList = [];
      if (cList != null && cList['message'] == 'success') {
        catList = cList['data'];
      }
      for (var i = 0; i < catList.length; i++) {
        var item = catList[i];
        var c = CategoryDB(
          id: int.parse(item['id'].toString()),
          uid: item['uid'] ?? item['id'].toString(),
          name: item['name'],
          parent: item['parent'] ?? '',
          isActive: item['isActive'] ?? true,
          isCustom: item['isCustom'] ?? false,
          description: item['description'] ?? '',
          inserter: item['inserter'] ?? 0,
          backup: 'ok',
        );
        await category.add(c);
      }
    }
    // if(branch.isEmpty){}
    if (productPrice.isEmpty) {
      for (var i = 0; i < product.values.length; i++) {
        ProductDB it = product.getAt(i)!;
        if (it.sellPriceList!.isNotEmpty) {
          for (var j = 0; j < it.sellPriceList!.length; j++) {
            ProductPriceDB p = ProductPriceDB(uid: ID.uidNew(), puid: it.uid, pro: {}, price: it.sellPriceList![j], name: 'قیمت ${j + 1}', defaultPrice: false, inserter: 0, backup: 'new');
            await SaveHelper.save(p);
          }
        } else if (it.sellPriceList!.isEmpty && (it.sellPrice ?? 0) > 0) {
          ProductPriceDB p = ProductPriceDB(uid: ID.uidNew(), puid: it.uid, pro: {}, price: it.sellPrice, name: 'قیمت اصلی', defaultPrice: false, inserter: 0, backup: 'new');
          await SaveHelper.save(p);
        }
      }
    }
    dbUpdate.value = false;
  }

  static remove(Box item) async {
    await item.deleteFromDisk();
  }

  static deleteFromDisk() async {
    await Hive.deleteFromDisk();
  }
}
