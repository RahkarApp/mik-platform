// ignore_for_file: empty_catches
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';

import 'package:mik_consts/dataType.dart';
import 'package:mik_router/routing.dart';
import 'package:mik_variables/variable.dart';

import 'package:mik_pages/bill/controller.dart';
import 'package:mik_pages/cheque/controller.dart';
import 'package:mik_pages/cost/controllers/cost.dart';
import 'package:mik_pages/cost/controllers/costCat.dart';
import 'package:mik_pages/customers/screen/screen.dart';
import 'package:mik_pages/invoice/controller.dart';
import 'package:mik_pages/invoice/detail/controller.dart';
import 'package:mik_pages/persons/controller.dart';
import 'package:mik_pages/product/screen/tabs/controllers/product.dart';
import 'package:mik_pages/product/screen/tabs/controllers/property.dart';
import 'package:mik_pages/product/screen/tabs/controllers/cat.dart';
import 'package:mik_pages/product/screen/tabs/controllers/store.dart';

import '../../../models/models.dart';
import '../../../utils/variable.dart';
import '../api.dart';
import 'socket.dart';
import 'socket_store.dart';

class SocketController {
  static final Object _replayEventKey = Object();

  /// Optional refresh hook for app-specific dashboards after shared pages update.
  static FutureOr<void> Function(Object? item, String dataType)? onDataChanged;

  static Future<void> _refresh<T>(FutureOr<dynamic> Function(T) refresh) async {
    if (Get.isRegistered<T>()) {
      await refresh(Get.find<T>());
    }
  }

  static lastData(data) async {
    try {
      if (data is List && data.isNotEmpty) {
        for (int i = 0; i < data.length; i++) {
          final myData = data[i];
          await runZoned(() async {
            if (myData['dataType'] == 'user') {
              await userS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'yarUser') {
              await yarUserS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'product') {
              await productS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'productPro') {
              await productProS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'productPrice') {
              await productPriceS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'productProperty') {
              await productPropertyS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'category') {
              await categoryS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'person') {
              await personS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'session') {
              await sessionS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'yarSession') {
              await yarSessionS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'partnerTransaction') {
              await partnerTransactionS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'invoice') {
              await invoiceS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'editInvoiceHistory') {
              await invoiceHistoryS(myData['type'], myData['data']);
            } else if ((myData['dataType'] == 'financialPerion' ||
                myData['dataType'] == 'financialPeriod')) {
              await financialPerionS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'commission') {
              await commissionS(myData['type'], myData['data']);
            } else if ((myData['dataType'] == 'settings' ||
                myData['dataType'] == 'setting')) {
              await settingsS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'cost') {
              await costS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'costCategory') {
              await costCategoryS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'bill') {
              await billS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'pattern') {
              await patternS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'sms') {
              await smsS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'cheque') {
              await chequeS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'warehouse') {
              await warehouseS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'warehouseName') {
              await warehouseNameS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'warehouseHistory') {
              await warehouseHistoryS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'connections') {
              await connectionsS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'yarPermission') {
              await yarPermissionS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'yarPermissionExt') {
              await yarPermissionExtS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'branch') {
              await branchS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'branchAccess') {
              await branchAccessS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'ticket') {
              await ticketS(myData['type'], myData['data']);
            } else if (myData['dataType'] == 'campaign') {
              await campaignS(myData['type'], myData['data']);
            }
          }, zoneValues: {_replayEventKey: myData});
        }
      }
    } catch (e) {}
  }

  static Future<bool> typeHandle(
    String dataType,
    int type,
    dynamic db,
    dynamic item,
  ) async {
    try {
      final byId = dataType == DataType.USER || dataType == DataType.YARUSER;
      final singleton = dataType == DataType.SETTINGS;
      final warehouseEdit = item is WarehouseDB && type != 2;
      Object? identityOf(dynamic record) => warehouseEdit
          ? (record.puid, record.wuid, record.prouid)
          : byId
          ? record.id
          : record.uid;
      final identity = singleton
          ? null
          : type == 2
          ? item
          : identityOf(item);
      final stored = await SocketStore.apply(
        box: db,
        operation: type,
        value: item,
        identity: identity,
        identityOf: identityOf,
        singleton: singleton,
      );
      var id = 0;
      String uid = '-';
      if (!singleton) {
        if (stored != null) {
          try {
            id = stored.id ?? 0;
          } catch (_) {}
          uid = byId ? '' : stored.uid ?? '-';
        } else {
          if (byId) {
            id = int.tryParse(item.toString()) ?? 0;
            uid = '';
          } else {
            uid = item.toString();
          }
        }
      }
      final replay = Zone.current[_replayEventKey];
      SKT.socket.emit(
        'geted_lastdata',
        replay is Map
            ? {
                'id': replay['id'],
                'uid': replay['uid'],
                'dataType': replay['dataType'],
              }
            : {'id': id, 'uid': uid, 'dataType': dataType},
      );
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error saving socket data ($dataType): $error\n$stackTrace');
      }
      return false;
    } finally {
      waitServer.value = false;
    }
  }

  static bool dataHandle(data, name) {
    if (data.toString().startsWith('error noInventory-')) {
      waitServer.value = false;
      Alert.error('تعدادی از کالاهای انتخاب شده موجودی ندارند.');
      return false;
    }
    switch (data) {
      case 'exist':
        waitServer.value = false;
        Alert.error('این $name از قبل وجود دارد');
        return false;
      case 'AccessDenied':
        waitServer.value = false;
        Alert.error('شما برای این کار دسترسی ندارید');
        return false;
      case 'error':
        waitServer.value = false;
        Alert.error('خطایی وجود دارد، مجددا تلاش کنید');
        return false;
      case null:
        waitServer.value = false;
        return false;
      default:
        return true;
    }
  }

  static alertHandle(item, String appEvent, editor) {
    // Analytics.event(appEvent);
    if (editor == 0) {
      switch (appEvent) {
        case 'add_invoice':
          if (item.runtimeType == InvoiceDB) {
            Alert.success('فاکتور با موفقیت ثبت شد');
          }
        case 'delete_invoice':
          if (item.runtimeType == InvoiceDB) {
            Alert.success('حذف فاکتور با موفقیت انجام شد');
          }
        case 'convert_invoice':
          if (item.runtimeType == InvoiceDB) {
            Alert.success('فاکتور با موفقیت ثبت شد');
          }
        case 'edit_invoice_status':
          if (item.runtimeType == InvoiceDB) {
            Alert.success('تغییر وضعیت اعمال شد');
          }
        case 'add_bill':
          if (item.runtimeType == BillDB) {
            Alert.success('صورتحساب با موفقیت ایجاد شد');
          }
        case 'delete_bill':
          if (item.runtimeType == BillDB) {
            Alert.success('صورتحساب حذف شد.');
          }
        case 'edit_bill':
          if (item.runtimeType == BillDB) {
            Alert.success('صورتحساب با موفقیت ویرایش شد');
          }
        case 'payment_bill':
          if (item.runtimeType == BillDB) {
            Alert.success('پرداخت با موفقیت ثبت شد.');
          }

        case 'pass_cheque':
          if (item.runtimeType == ChequeDB) {
            Alert.success('چک به وضیعت پاس شده تغییر کرد.');
          }
        case 'delete_cheque':
          if (item.runtimeType == ChequeDB) {
            Alert.success('چک با موفقیت ثبت شد');
          }
        case 'edit_cheque':
          if (item.runtimeType == ChequeDB) {
            Alert.success('چک با موفقیت ویرایش شد');
          }
        case 'add_cost':
          if (item.runtimeType == CostDB) {
            Alert.success('هزینه با موفقیت ثبت شد');
          }
        case 'delete_cost':
          if (item.runtimeType == CostDB) {
            Alert.success('حذف هزینه با موفقیت انجام شد');
          }
        case 'edit_cost':
          if (item.runtimeType == CostDB) {
            Alert.success('هزینه با موفقیت ویرایش شد');
          }
        case 'payment_cost':
          if (item.runtimeType == CostDB) {
            Alert.success('پرداخت با موفقیت برای هزینه ${item.id} ثبت شد.');
          }
        case 'add_product':
          if (item.runtimeType == ProductDB) {
            Alert.success('محصول با موفقیت اضافه شد');
          }
        case 'edit_product':
          if (item.runtimeType == ProductDB) {
            Alert.success('اطلاعات محصول با موفقیت ویرایش شد');
          }
        case 'add_cat':
          if (item.runtimeType == CategoryDB ||
              item.runtimeType == CostCategoryDB) {
            Alert.success('دسته بندی با موفقیت ایجاد شد');
          }
        case 'edit_cat':
          if (item.runtimeType == CategoryDB ||
              item.runtimeType == CostCategoryDB) {
            Alert.success('دسته بندی با موفقیت ویرایش شد');
          }
        case 'add_person':
          if (item.runtimeType == PersonDB) {
            Alert.success('اطلاعات با موفقیت ذخیره شد');
          }
        case 'edit_person':
          if (item.runtimeType == PersonDB) {
            Alert.success('اطلاعات با موفقیت ذخیره شد');
          }
        case 'add_CRM':
          if (item.runtimeType == ConnectionDB) {
            Alert.success('اطلاعات با موفقیت ذخیره شد.');
          }
        case 'delete_partnerTransaction':
          if (item.runtimeType == PartnerTransactionDB) {
            Alert.success('حذف تراکنش با موفقیت انجام شد.');
          }
        case 'add_partnerTransaction':
          if (item.runtimeType == PartnerTransactionDB) {
            Alert.success(' تراکنش با موفقیت انجام شد.');
          }

        case 'add_warehouse':
          if (item.runtimeType == WarehouseDB) {
            Alert.success('انبار با موفقیت اضافه شد');
          }
        case 'edit_warehouse':
          if (item.runtimeType == WarehouseDB) {
            Alert.success('انبار با موفقیت ویرایش شد');
          }
        case 'add_warehouseHistory':
          if (item.runtimeType == WarehouseDB) {
            Alert.success('انبار با موفقیت ویرایش شد');
          }
        case 'edit_profile':
          if (item.runtimeType == ProfileDB || item.runtimeType == MiKYarDB) {
            Alert.success('تغییرات با موفقیت ذخیره شد.');
          }
      }
    }
  }

  static Future<void> backHandle(bool? isBack, data) async {
    if (isBack != null) {
      if (isBack && data == 0) {
        Get.back();
        if (kDebugMode) print('back==============back');
      }
    }
  }

  static Future<void> initPage(Object? item, String dataType) async {
    final route = Get.currentRoute.split('?').first;
    final invoiceChanged = item is InvoiceDB || dataType == DataType.INVOICE;
    final personChanged = item is PersonDB || dataType == DataType.PERSON;
    final billChanged = item is BillDB || dataType == DataType.BILL;
    final productChanged = item is ProductDB || dataType == DataType.PRODUCT;
    final warehouseChanged =
        item is WarehouseDB || dataType == DataType.WAREHOUSE;

    // Refresh only controllers already created by a shared page.
    if (invoiceChanged ||
        productChanged ||
        warehouseChanged ||
        item is ProductProDB ||
        dataType == DataType.PRODUCTPRO ||
        item is ProductPriceDB ||
        dataType == DataType.PRODUCTPRICE) {
      await _refresh<ProductTabDashboardController>((c) => c.init());
    }
    if (item is ProductPropertyDB || dataType == DataType.PRODUCTPROPERTY) {
      await _refresh<ProductPropertyTabDashboardController>((c) => c.init());
    }
    if (item is CategoryDB || dataType == DataType.CATEGORY) {
      await _refresh<CatTabDashboardController>((c) => c.init());
    }
    if (invoiceChanged ||
        productChanged ||
        warehouseChanged ||
        item is WarehouseNameDB ||
        dataType == DataType.WAREHOUSENAME) {
      await _refresh<WarehouseTabDashboardController>((c) => c.init());
    }
    if (personChanged) {
      await _refresh<CustomerTabDashboardController>((c) => c.init());
      final personType = switch (route) {
        RoutesName.PARTNER => 'partner',
        RoutesName.SUPPLIER => 'supplier',
        RoutesName.SERVICER => 'servicer',
        _ => null,
      };
      if (personType != null) {
        await _refresh<PersonScreenController>((c) => c.init(personType));
      }
    }
    if (item is ConnectionDB || dataType == DataType.CRM) {
      await _refresh<CRMTabDashboardController>((c) => c.init());
    }
    if (route == RoutesName.INVOICES && invoiceChanged) {
      await _refresh<InvoiceScreenController>((c) async {
        await c.init();
        c.change.toggle();
      });
    }
    if (route == RoutesName.INVOICEDETAIL && (invoiceChanged || billChanged)) {
      await _refresh<InvoiceDetailsScreenController>((c) async {
        // Deletion payloads contain a UID rather than an InvoiceDB.
        // Do not pass them as the currently displayed invoice model.
        await c.init(itemFactor: item is InvoiceDB ? item : null);
      });
    }
    if (route == RoutesName.BILL && billChanged) {
      await _refresh<BillScreenController>((c) => c.init());
    }
    if (route == RoutesName.COST) {
      if (item is CostDB || dataType == DataType.COST) {
        await _refresh<CostScreenController>((c) => c.init());
      }
      if (item is CostCategoryDB || dataType == DataType.COSTCATEGORY) {
        await _refresh<CostCatScreenController>((c) => c.init());
      }
    }
    if (route == RoutesName.CHEQUE &&
        (item is ChequeDB || dataType == DataType.CHEQUE)) {
      await _refresh<ChequeScreenController>((c) => c.init());
    }
    await onDataChanged?.call(item, dataType);
  }

  //===========================================================<user>=================================================================
  static Future userS(type, data) async {
    if (dataHandle(data, 'فرد')) {
      var item;
      if (type != 2) {
        item = ProfileDB(
          address: data['address'],
          id: data['id'],
          instagram: data['instagram'],
          name: data['name'],
          postalCode: data['postalCode'],
          img: '',
          date: data['date'],
          cardNumber: data['cardNumber'],
          shebaNumber: data['shebaNumber'],
          cardNumberName: data['cardNumberName'],
          province: data['province'],
          city: data['city'],
          email: data['email'],
          tel: data['tel'],
          site: data['site'],
          mobile: data['mobile'],
          slogan: data['slogan'],
          referral: data['referral'],
          type: data['type'],
          nationalID: data['nationalID'] ?? '',
          economicCode: data['economicCode'] ?? '',
          tspEnabled: data['tspEnabled'] ?? false,
          stateID: 0,
          townID: 0,
          backup: 'ok',
        );
      } else {
        item = data['id'] ?? data['uid'];
      }
      if (!await typeHandle('user', type, profile, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.USER);
    }
  }

  static getUserS(data) {
    try {
      if (dataHandle(data, 'قرد')) {
        profile.clear();
        ProfileDB item = ProfileDB(
          address: data['address'],
          id: data['id'],
          instagram: data['instagram'],
          name: data['name'],
          postalCode: data['postalCode'],
          img: '',
          date: data['date'],
          cardNumber: data['cardNumber'],
          shebaNumber: data['shebaNumber'],
          cardNumberName: data['cardNumberName'],
          province: data['province'],
          city: data['city'],
          email: data['email'],
          tel: data['tel'],
          site: data['site'],
          mobile: data['mobile'],
          slogan: data['slogan'],
          referral: data['referral'],
          type: data['type'],
          nationalID: data['nationalID'] ?? '',
          economicCode: data['economicCode'] ?? '',
          tspEnabled: data['tspEnabled'] ?? false,
          stateID: 0,
          townID: 0,
          backup: 'ok',
        );
        profile.add(item);
      }
    } catch (e) {}
  }

  //===========================================================<yarUser>=================================================================

  static yarUserS(type, data) async {
    if (dataHandle(data, 'فرد')) {
      var item;
      if (type != 2) {
        item = MiKYarDB(
          id: data['id'],
          mobile: data['mobile'],
          name: data['name'],
          post: data['post'],
          permission: data['permission'],
          permissionUID: data['permissionUID'],
          inserter: data['inserter'],
          active: data['active'],
          backup: 'ok',
        );
      } else {
        item = data['id'] ?? data['uid'];
      }
      if (!await typeHandle(DataType.YARUSER, type, mikyar, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.YARUSER);
    }
  }

  static getYarUserS(data) async {
    if (dataHandle(data, 'فرد')) {
      await mikyar.clear();
      try {
        for (var i = 0; i < data.length; i++) {
          MiKYarDB ch = MiKYarDB(
            id: data[i]['id'],
            mobile: data[i]['mobile'],
            name: data[i]['name'],
            post: data[i]['post'],
            permission: data[i]['permission'],
            permissionUID: data[i]['permissionUID'],
            inserter: data[i]['inserter'],
            active: data[i]['active'],
            backup: 'ok',
          );
          await mikyar.add(ch);
        }
      } catch (e) {}
    }
  }

  //===========================================================<product>=================================================================

  static productS(type, data) async {
    if (dataHandle(data, 'محصول')) {
      var item;
      if (type != 2) {
        List<String> prdIMG = [];
        for (var g = 0; g < data['img'].length; g++) {
          prdIMG.add(await API.getIMG('product', data['id'], data['img'][g]));
        }
        item = ProductDB(
          id: data['id'],
          uid: data['uid'],
          taxID: data['taxID'],
          inserter: data['inserter'],
          peropertyID: data['peropertyID'],
          name: data['name'],
          img: data['img'],
          archive: data['archive'] ?? false,
          categoryID: data['categoryID'],
          barcode: data['barcode'],
          description: data['description'] ?? '',
          sellPrice: data['sellPrice'],
          commission: double.parse((data['commission'] ?? 0).toString()),
          isCommissionFixed: data['isCommissionFixed'],
          date: data['date'],
          inventory: double.parse((data['inventory'] ?? 0).toString()),
          inventoryControl: data['inventoryControl'] ?? 'normal',
          type: data['type'] ?? 'product',
          vat: double.tryParse(data['vat'].toString()) ?? 0.0,
          sellPriceList:
              data['sellPriceList'] == null || data['sellPriceList'].isEmpty
              ? <int>[data['sellPrice'] ?? 0]
              : List<int>.from(data['sellPriceList']),
          catIDList: data['catIDList'] == null || data['catIDList'].isEmpty
              ? <String>[data['categoryID']]
              : List<String>.from(data['catIDList']),
          unitCode: data['unitCode'] ?? 0,
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.PRODUCT, type, product, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PRODUCT);
    }
  }

  static getProductS(data) async {
    if (dataHandle(data, 'محصول')) {
      await product.clear();

      for (var i = 0; i < data.length; i++) {
        List<String> prdIMG = [];
        for (var g = 0; g < data[i]['img'].length; g++) {
          prdIMG.add(
            await API.getIMG('product', data[i]['id'], data[i]['img'][g]),
          );
        }
        ProductDB prd = ProductDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          taxID: data[i]['taxID'],
          name: data[i]['name'],
          inserter: data['inserter'],
          peropertyID: data['peropertyID'],
          img: data['img'],
          archive: data[i]['archive'] ?? false,
          categoryID: data[i]['categoryID'],
          barcode: data[i]['barcode'],
          description: data[i]['description'],
          sellPrice: data[i]['sellPrice'],
          commission: double.parse(data[i]['commission'].toString()),
          isCommissionFixed: data[i]['isCommissionFixed'],
          date: data[i]['date'],
          inventory: double.parse(data[i]['inventory'].toString()),
          inventoryControl: data[i]['inventoryControl'],
          type: data[i]['type'] ?? 'product',
          vat: double.tryParse(data[i]['vat'].toString()) ?? 0.0,
          sellPriceList:
              data[i]['sellPriceList'] == null ||
                  data[i]['sellPriceList'].isEmpty
              ? <int>[data[i]['sellPrice']]
              : List<int>.from(data[i]['sellPriceList']),
          catIDList:
              data[i]['catIDList'] == null || data[i]['catIDList'].isEmpty
              ? <String>[data[i]['categoryID']]
              : List<String>.from(data[i]['catIDList']),
          unitCode: data[i]['unitCode'] ?? 0,
          backup: 'ok',
        );

        await product.add(prd);
      }
    }
  }

  static productProS(type, data) async {
    if (dataHandle(data, 'محصول ویژه')) {
      var item;
      if (type != 2) {
        item = ProductProDB(
          uid: data['uid'],
          inserter: data['inserter'],
          productUID: data['productUID'],
          property: data['property'],
          desc: data['desc'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.PRODUCTPRO, type, productPro, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PRODUCTPRO);
    }
  }

  static getProductProS(data) async {
    if (dataHandle(data, 'محصول ویژه')) {
      await productPro.clear();
      for (var i = 0; i < data.length; i++) {
        ProductProDB item = ProductProDB(
          uid: data[i]['uid'],
          inserter: data[i]['inserter'],
          productUID: data[i]['productUID'],
          property: data[i]['property'],
          desc: data[i]['desc'],
          backup: 'ok',
        );
        await productPro.add(item);
      }
    }
  }

  static productPriceS(type, data) async {
    if (dataHandle(data, 'قیمت محصول')) {
      var item;
      if (type != 2) {
        item = ProductPriceDB(
          uid: data['uid'],
          puid: data['puid'],
          pro: data['pro'],
          price: data['price'],
          name: data['name'],
          defaultPrice: data['defaultPrice'],
          dateValid: data['dateValid'],
          inserter: data['inserter'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }

      if (!await typeHandle(DataType.PRODUCTPRICE, type, productPrice, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PRODUCTPRICE);
    }
  }

  static getProductPriceS(data) async {
    if (dataHandle(data, 'قیمت محصول')) {
      await productPro.clear();
      for (var i = 0; i < data.length; i++) {
        ProductPriceDB item = ProductPriceDB(
          uid: data[i]['uid'],
          puid: data[i]['puid'],
          pro: data[i]['pro'],
          price: data[i]['price'],
          name: data[i]['name'],
          defaultPrice: data[i]['defaultPrice'],
          dateValid: data[i]['dateValid'],
          inserter: data[i]['inserter'],
          backup: 'ok',
        );
        await productPrice.add(item);
      }
    }
  }

  static productPropertyS(type, data) async {
    if (dataHandle(data, 'ویژگی محصول')) {
      var item;
      if (type != 2) {
        item = ProductPropertyDB(
          uid: data['uid'],
          inserter: data['inserter'],
          name: data['name'],
          value: data['value'],
          type: data['type'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.PRODUCTPROPERTY,
        type,
        productProperty,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PRODUCTPROPERTY);
    }
  }

  static getProductPropertyS(data) async {
    if (dataHandle(data, 'ویژگی محصول')) {
      await productProperty.clear();
      for (var i = 0; i < data.length; i++) {
        ProductPropertyDB item = ProductPropertyDB(
          uid: data[i]['uid'],
          inserter: data[i]['inserter'],
          name: data[i]['name'],
          value: data[i]['value'],
          type: data[i]['type'],
          backup: 'ok',
        );
        await productProperty.add(item);
      }
    }
  }

  //===========================================================<category>=================================================================

  static categoryS(type, data) async {
    if (dataHandle(data, 'دسته بندی')) {
      var item;
      if (type != 2) {
        item = CategoryDB(
          inserter: data['inserter'],
          type: data['type'],
          uid: data['uid'],
          parent: data['parent'],
          id: data['id'],
          name: data['name'],
          description: data['description'],
          isActive: data['isActive'] ?? true,
          isCustom: data['isCustom'] ?? false,
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.CATEGORY, type, category, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.CATEGORY);
    }
  }

  static getCategoryS(data) async {
    if (dataHandle(data, 'دسته بندی')) {
      category.clear();
      for (var i = 0; i < data.length; i++) {
        CategoryDB cat = CategoryDB(
          inserter: data['inserter'],
          type: data['type'],
          parent: data[i]['parent'],
          uid: data[i]['uid'],
          id: data[i]['id'],
          name: data[i]['name'],
          description: data[i]['description'],
          isActive: data['isActive'],
          isCustom: data['isCustom'],
          backup: 'ok',
        );
        await category.add(cat);
      }
    }
  }

  //===========================================================<person>=================================================================

  static personS(type, data) async {
    if (dataHandle(data, 'فرد')) {
      var item;
      if (type != 2) {
        item = PersonDB(
          uid: data['uid'],
          id: data['id'],
          date: data['date'],
          inserter: data['inserter'],
          name: data['name'],
          nationalID: data['nationalID'],
          mobile: data['mobile'],
          instagram: data['instagram'],
          email: data['email'],
          cardNumber: data['cardNumber'],
          shebaNumber: data['shebaNumber'],
          address: data['address'],
          isAdmin: data['isAdmin'],
          isSupplier: data['isSupplier'],
          isPartner: data['isPartner'],
          isCustomer: data['isCustomer'],
          isMarketer: data['isMarketer'],
          isService: data['isService'],
          description: data['description'],
          stateID: data['stateID'],
          townID: data['townID'],
          org: data['org'] ?? false,
          orgName: data['orgName'] ?? '',
          tel: data['tel'] ?? '',
          economicID: data['economicID'] ?? '',
          postalCode: data['postalCode'] ?? '',
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.PERSON, type, person, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PERSON);
    }
  }

  static getPersonS(data) async {
    if (dataHandle(data, 'فرد')) {
      await person.clear();
      for (var i = 0; i < data.length; i++) {
        PersonDB prs = PersonDB(
          uid: data[i]['uid'],
          id: data[i]['id'],
          date: data[i]['date'],
          inserter: data['inserter'],
          name: data[i]['name'],
          nationalID: data[i]['nationalID'],
          mobile: data[i]['mobile'],
          instagram: data[i]['instagram'],
          email: data[i]['email'],
          cardNumber: data[i]['cardNumber'],
          shebaNumber: data[i]['shebaNumber'],
          address: data[i]['address'],
          isAdmin: data[i]['isAdmin'],
          isSupplier: data[i]['isSupplier'],
          isPartner: data[i]['isPartner'],
          isCustomer: data[i]['isCustomer'],
          isMarketer: data[i]['isMarketer'],
          isService: data[i]['isService'],
          description: data[i]['decription'],
          stateID: data[i]['stateID'],
          townID: data[i]['townID'],
          org: data[i]['org'] ?? false,
          orgName: data[i]['orgName'] ?? '',
          tel: data[i]['tel'] ?? '',
          economicID: data[i]['economicID'] ?? '',
          postalCode: data[i]['postalCode'] ?? '',
          backup: 'ok',
        );
        await person.add(prs);
      }
    }
  }

  //===========================================================<session>=================================================================

  static sessionS(type, data) {
    //save session data in local storage
  }

  static getSessionS(data) {
    //get session data and save in local host
  }

  //===========================================================<yar session>=================================================================

  static yarSessionS(type, data) {
    //save yarSession data in local storage
  }

  static getYarSessionS(data) {
    //get yarSession data and save in local host
  }

  //===========================================================<partner transaction>=================================================================

  static partnerTransactionS(type, data) async {
    if (dataHandle(data, 'شریک')) {
      var item;
      if (type != 2) {
        item = PartnerTransactionDB(
          id: data['id'],
          uid: data['uid'],
          partnerUID: data['partnerUID'],
          partnerID: data['partnerID'],
          description: data['description'],
          inserter: data['inserter'],
          amount: data['amount'],
          status: data['status'],
          date: data['date'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.PARTNERTRANSACTIN,
        type,
        partnerTransaction,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PARTNERTRANSACTIN);
    }
  }

  static getPartnerTransactionS(data) async {
    if (dataHandle(data, 'فرد')) {
      await partnerTransaction.clear();
      for (var i = 0; i < data.length; i++) {
        PartnerTransactionDB ins = PartnerTransactionDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          partnerUID: data[i]['partnerUID'],
          description: data['description'],
          inserter: data['inserter'],
          partnerID: data[i]['partnerID'],
          amount: data[i]['amount'],
          status: data[i]['status'],
          date: data[i]['date'],
          backup: 'ok',
        );
        await partnerTransaction.add(ins);
      }
    }
  }

  //===========================================================<invoice>=================================================================

  static invoiceS(type, data) async {
    if (dataHandle(data, 'فاکتور')) {
      var item;
      if (type != 2) {
        item = InvoiceDB(
          id: data['id'] ?? 0,
          uid: data['uid'],
          personUID: data['personUID'],
          branchUID: data['branchUID'],
          items: data['items'],
          billUID: List<String>.from(data['billUID']),
          date: data['date'],
          doc: data['doc'],
          parameters: data['parameters'],
          type: data['type'],
          shipping: data['shipping'],
          status: data['status'],
          commission: data['commission'],
          description: data['description'],
          inserter: data['inserter'],
          backup: 'ok',
        );

        // item = FactorDB(
        //     id: data['id'],
        //     billUID: List<String>.from(data['billUID']),
        //     shippingCompany: data['shippingCompany'],
        //     trakingCode: data['trakingCode'],
        //     productID: data['productID'],
        //     cRecipientUID: data['cRecipientUID'],
        //     personUID: data['personUID'],
        //     productUID: data['productUID'],
        //     amount: data['amount'],
        //     buyPrice: data['buyPrice'],
        //     sellPrice: data['sellPrice'],
        //     personID: data['personID'],
        //     doc: data['doc'],
        //     isBuy: data['isBuy'],
        //     excess: data['excess'],
        //     shippingCost: data['shippingCost'],
        //     status: data['status'],
        //     statusDate: data['statusDate'],
        //     editDate: data['editDate'],
        //     commission: data['commission'],
        //     cRecipient: data['cRecipient'],
        //     cStatus: data['cStatus'],
        //     discount: data['discount'],
        //     isDiscountFixed: data['isDiscountFixed'],
        //     description: data['description'],
        //     date: data['date'],
        //     billID: data['billID'],
        //     uuid: data['uuid'],
        //     type: data['type'],
        //     vat: data['vat'],
        //     vatCalculated: data['vatCalculated'],
        //     inserter: data['inserter'],
        //     backup: 'ok');
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.INVOICE, type, invoice, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.INVOICE);
    }
  }

  static getInvoiceS(data) async {
    if (dataHandle(data, 'فاکتور')) {
      await invoice.clear();
      for (int i = 0; i < data.length; i++) {
        InvoiceDB inv = InvoiceDB(
          id: data[i]['id'] ?? 0,
          uid: data[i]['uid'],
          personUID: data[i]['personUID'],
          branchUID: data[i]['branchUID'],
          items: data[i]['items'],
          billUID: data[i]['billUID'],
          date: data[i]['date'],
          doc: data[i]['doc'],
          parameters: data[i]['parameters'],
          type: data[i]['type'],
          shipping: data[i]['shipping'],
          status: data[i]['status'],
          commission: data[i]['commission'],
          description: data[i]['description'],
          inserter: data[i]['inserter'],
          backup: 'ok',
        );
        await invoice.add(inv);
      }
    }
  }

  static invoiceHistoryS(type, data) async {
    if (dataHandle(data, 'تاریخچه ویرایش فاکتور')) {
      var item;
      if (data['type'] != 2) {
        item = EditInvoiceHistoryDB(
          uid: data['uid'],
          invoiceUID: data['invoiceUID'],
          oldData: data['oldData'],
          newData: data['newData'],
          date: data['date'],
          editor: data['editor'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.EDITINVOICEHISTORY,
        type,
        editInvoiceHistory,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.EDITINVOICEHISTORY);
    }
  }
  //===========================================================<financialPerion>=================================================================

  static financialPerionS(type, data) {}
  static getFinancialPerionS(data) async {}

  //===========================================================<commission>=================================================================

  static commissionS(type, data) async {
    if (dataHandle(data, 'کمیسیون')) {
      var item;
      if (type != 2) {
        item = CommissionDB(
          id: data['id'],
          uid: data['uid'],
          factorUID: data['factorUID'],
          inserter: data['inserter'],
          personID: data['personID'],
          factorID: data['factorID'],
          amount: data['amount'],
          type: data['type'],
          description: data['description'],
          date: data['date'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.COMMISSION, type, commission, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.COMMISSION);
    }
  }

  static getCommissionS(data) async {
    if (dataHandle(data, 'کمیسیون')) {
      await commission.clear();
      for (var i = 0; i < data.length; i++) {
        CommissionDB cms = CommissionDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          factorUID: data[i]['factorUID'],
          inserter: data['inserter'],
          personID: data[i]['personID'],
          factorID: data[i]['factorID'],
          amount: data[i]['amount'],
          type: data[i]['type'],
          description: data[i]['description'],
          date: data[i]['date'],
          backup: 'ok',
        );
        await commission.add(cms);
      }
    }
  }

  //===========================================================<setting>=================================================================

  static settingsS(type, data) async {
    if (dataHandle(data, 'تنظیمات')) {
      SendSmsSetting smsSet = SendSmsSetting(
        orderSubmit: data['sendSms']['orderSubmit'],
        orderSended: data['sendSms']['orderSended'],
        orderReadySend: data['sendSms']['orderReadySend'],
        orderDelayTanks: data['sendSms']['orderDelayTanks'],
        orderCancelled: data['sendSms']['orderCancelled'],
        orderReturned: data['sendSms']['orderReturned'],
        orderOnlinePay: data['sendSms']['orderOnlinePay'],
        preFactor: data['sendSms']['preFactor'],
      );
      SettingsData setting = SettingsData(
        darkMode: data['darkMode'],
        dayForCancel: data['dayForCancel'],
        animation: data['animation'],
        factorType: data['factorType'],
        factorText: data['factorText'],
        factorColor1: data['factorColor1'],
        factorColor2: data['factorColor2'],
        dayForPreFactor: data['dayForPreFactor'],
        usePreFactor: data['usePreFactor'],
        sendSms: smsSet,
        skipInit: false,
        factorLink: data['factorLink'],
        factorVat: data['factorVat'],
        factorSize: data['factorSize'],
        factorIsRial: data['factorIsRial'],
        connectionStatus: List<String>.from(data['connectionStatus']),
        profitInInvoice: data['profitInInvoice'],
        backup: 'ok',
      );

      if (!await typeHandle(DataType.SETTINGS, type, settingsData, setting))
        return;
      await alertHandle(
        setting,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(setting, DataType.SETTINGS);
    }
  }

  static getSettingS(data) async {
    if (dataHandle(data, 'تنظیمات')) {
      await settingsData.clear();
      SendSmsSetting smsSet = SendSmsSetting(
        orderSubmit: data['sendSms']['orderSubmit'],
        orderSended: data['sendSms']['orderSended'],
        orderReadySend: data['sendSms']['orderReadySend'],
        orderDelayTanks: data['sendSms']['orderDelayTanks'],
        orderCancelled: data['sendSms']['orderCancelled'],
        orderOnlinePay: data['sendSms']['orderOnlinePay'],
        orderReturned: data['sendSms']['orderReturned'],
        preFactor: data['sendSms']['preFactor'],
      );
      SettingsData setting = SettingsData(
        darkMode: data['darkMode'],
        dayForCancel: data['dayForCancel'],
        animation: data['animation'],
        factorType: data['factorType'],
        factorText: data['factorText'],
        factorColor1: data['factorColor1'],
        factorColor2: data['factorColor2'],
        dayForPreFactor: data['dayForPreFactor'],
        usePreFactor: data['usePreFactor'],
        sendSms: smsSet,
        skipInit: false,
        factorLink: data['factorLink'],
        factorVat: data['factorVat'],
        factorSize: data['factorSize'],
        factorIsRial: data['factorIsRial'],
        connectionStatus: List<String>.from(data['connectionStatus']),
        profitInInvoice: data['profitInInvoice'],
        backup: 'ok',
      );
      await settingsData.add(setting);
    }
  }

  //===========================================================<cost>=================================================================

  static costS(type, data) async {
    if (dataHandle(data, 'هزینه')) {
      var item;
      if (type != 2) {
        item = CostDB(
          id: data['id'],
          uid: data['uid'],
          billUID: List<String>.from(data['billUID']),
          categoryUID: data['categoryUID'],
          factorUID: data['factorUID'],
          personUID: data['personUID'],
          inserter: data['inserter'],
          categoryID: data['categoryID'],
          name: data['name'],
          description: data['description'],
          price: data['price'],
          factorID: data['factorID'],
          personID: data['personID'],
          date: data['date'],
          billID: data['billID'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.COST, type, cost, item)) return;
      await alertHandle(
        item,
        data?['appEvent'] ?? 'receive_data',
        data?['editor'] ?? '',
      );
      await backHandle(type == 2 ? true : data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.COST);
    }
  }

  static getCostS(data) async {
    if (dataHandle(data, 'هزینه')) {
      await cost.clear();
      for (var i = 0; i < data['cost'].length; i++) {
        CostDB item = CostDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          billUID: List<String>.from(data[i]['billUID']),
          categoryUID: data[i]['categoryUID'],
          factorUID: data[i]['factorUID'],
          personUID: data[i]['personUID'],
          inserter: data['inserter'],
          categoryID: data[i]['categoryID'],
          name: data[i]['name'],
          description: data[i]['description'],
          price: data[i]['price'],
          factorID: data[i]['factorID'],
          personID: data[i]['personID'],
          date: data[i]['date'],
          billID: data[i]['billID'],
          backup: 'ok',
        );
        await cost.add(item);
      }
    }
  }

  //===========================================================<cost category>=================================================================

  static costCategoryS(type, data) async {
    if (dataHandle(data, 'دسته بندی')) {
      var item;
      if (type != 2) {
        item = CostCategoryDB(
          id: data['id'],
          uid: data['uid'],
          inserter: data['inserter'],
          name: data['name'],
          description: data['description'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.COSTCATEGORY, type, costCategory, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.COSTCATEGORY);
    }
  }

  static getCostCategory(data) async {
    if (dataHandle(data, 'دسته بندی')) {
      await costCategory.clear();
      for (var i = 0; i < data.length; i++) {
        CostCategoryDB item = CostCategoryDB(
          id: data[i]['id'],
          inserter: data['inserter'],
          uid: data[i]['uid'],
          name: data[i]['name'],
          description: data[i]['description'],
          backup: 'ok',
        );
        await costCategory.add(item);
      }
    }
  }

  //===========================================================<bill>=================================================================

  static billS(type, data) async {
    if (dataHandle(data, 'صورتحساب')) {
      var item;
      if (type != 2) {
        item = BillDB(
          id: data['id'],
          uid: data['uid'],
          toUID: data['toUID'],
          inserter: data['inserter'],
          creditorUID: data['creditorUID'],
          debtorUID: data['debtorUID'],
          debtor: data['debtor'],
          creditor: data['creditor'],
          total: data['total'],
          paid: data['paid'],
          unPaid: data['unPaid'],
          to: data['to'],
          date: data['date'],
          deadLine: data['deadLine'],
          type: data['type'],
          meta: data['meta'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }

      if (!await typeHandle(DataType.BILL, type, bill, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.BILL);
    }
  }

  static getBillS(data) async {
    if (dataHandle(data, 'صورتحساب')) {
      await bill.clear();
      for (var i = 0; i < data.length; i++) {
        BillDB item = BillDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          toUID: data[i]['toUID'],
          inserter: data[i]['inserter'],
          debtor: data[i]['debtor'],
          creditor: data[i]['creditor'],
          creditorUID: data[i]['creditorUID'],
          debtorUID: data[i]['debtorUID'],
          total: data[i]['total'],
          paid: data[i]['paid'],
          unPaid: data[i]['unPaid'],
          to: data[i]['to'],
          date: data[i]['date'],
          deadLine: data[i]['deadLine'],
          type: data[i]['type'],
          meta: data[i]['meta'],
          backup: 'ok',
        );
        await bill.add(item);
      }
    }
  }

  //===========================================================<pattern>=================================================================

  static patternS(type, data) async {
    if (dataHandle(data, 'الگو')) {
      var item;
      if (type != 2) {
        item = PatternDB(
          code: data['code'],
          orderType: data['orderType'],
          text: data['text'],
          inserter: data['inserter'],
          pattern: data['pattern'],
          status: data['status'],
          active: data['active'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.PATTERN, type, pattern, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.PATTERN);
    }
  }

  static getPatternS(data) async {
    if (dataHandle(data, 'الگو')) {
      await pattern.clear();
      for (var i = 0; i < data.length; i++) {
        PatternDB pt = PatternDB(
          code: data[i]['code'],
          orderType: data[i]['orderType'],
          inserter: data['inserter'],
          text: data[i]['text'],
          pattern: data[i]['pattern'],
          status: data[i]['status'],
          active: data[i]['active'],
          backup: 'ok',
        );
        await pattern.add(pt);
      }
    }
  }
  //===========================================================<sms>=================================================================

  static smsS(type, data) async {
    if (dataHandle(data, 'پیام')) {
      var item;
      if (type != 2) {
        SmsPatternValue spv = SmsPatternValue(
          date: data['patternValue']['date'],
          factorID: data['patternValue']['factorID'].toString(),
          link: data['patternValue']['link'],
          name: data['patternValue']['name'],
          price: data['patternValue']['price'],
        );
        item = SMS(
          personID: data['personID'],
          patternCode: data['patternCode'],
          smsPatternValue: spv,
          inserter: data['inserter'],
          mobile: data['mobile'],
          status: data['status'],
          bulk: data['bulk'],
          date: data['date'],
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.SMS, type, sms, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.SMS);
    }
  }

  static getSmsS(data) async {
    if (dataHandle(data, 'پیام')) {
      if (data != null) {
        await sms.clear();
        for (var i = 0; i < data.length; i++) {
          SmsPatternValue spv = SmsPatternValue(
            date: data[i]['patternValue']['date'],
            factorID: data[i]['patternValue']['factorID'].toString(),
            link: data[i]['patternValue']['link'],
            name: data[i]['patternValue']['name'],
            price: data[i]['patternValue']['price'],
          );
          SMS s = SMS(
            personID: data[i]['personID'],
            patternCode: data[i]['patternCode'],
            smsPatternValue: spv,
            inserter: data['inserter'],
            mobile: data[i]['mobile'],
            status: data[i]['status'],
            bulk: data[i]['bulk'],
            date: data[i]['date'],
          );
          await sms.add(s);
        }
      }
    }
  }
  //===========================================================<chque>=================================================================

  static chequeS(type, data) async {
    if (dataHandle(data, 'چک')) {
      var item;
      if (type != 2) {
        item = ChequeDB(
          id: data['id'],
          uid: data['uid'],
          toUID: data['toUID'],
          inserter: data['inserter'],
          billID: data['billID'],
          billUID: data['billUID'],
          holderUID: data['holderUID'],
          payeeUID: data['payeeUID'],
          accNo: data['accNo'],
          bankID: data['bankID'],
          branch: data['branch'],
          branchNo: data['branchNo'],
          chequeNo: data['chequeNo'],
          date: data['date'],
          desc: data['desc'],
          dueDate: data['dueDate'],
          holder: data['holder'],
          payee: data['payee'],
          price: data['price'],
          status: data['status'],
          to: data['to'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.CHEQUE, type, cheque, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.CHEQUE);
    }
  }

  static getChequeS(data) async {
    if (dataHandle(data, 'چک')) {
      await cheque.clear();
      for (var i = 0; i < data.length; i++) {
        ChequeDB ch = ChequeDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          toUID: data[i]['toUID'],
          inserter: data['inserter'],
          billUID: data[i]['billUID'],
          billID: data[i]['billID'],
          accNo: data[i]['accNo'],
          bankID: data[i]['bankID'],
          branch: data[i]['branch'],
          holderUID: data[i]['holderUID'],
          payeeUID: data[i]['payeeUID'],
          branchNo: data[i]['branchNo'],
          chequeNo: data[i]['chequeNo'],
          date: data[i]['date'],
          desc: data[i]['desc'],
          dueDate: data[i]['dueDate'],
          holder: data[i]['holder'],
          payee: data[i]['payee'],
          price: data[i]['price'],
          status: data[i]['status'],
          to: data[i]['to'],
          backup: 'ok',
        );
        await cheque.add(ch);
      }
    }
  }
  //===========================================================<warehouse>=================================================================

  static warehouseS(type, data) async {
    if (dataHandle(data, 'انبار')) {
      var item;
      if (type != 2) {
        item = WarehouseDB(
          id: data['id'],
          uid: data['uid'],
          inserter: data['inserter'],
          wuid: data['wuid'],
          puid: data['puid'],
          prouid: data['prouid'],
          inventory: double.parse(data['inventory'].toString()),
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.WAREHOUSE, type, warehouse, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.WAREHOUSE);
    }
  }

  static warehouseEditBulk(data) async {
    //try {
    for (var i = 0; i < data['changes'].length; i++) {
      var item = WarehouseDB(
        id: data['changes'][i]['id'],
        uid: data['changes'][i]['uid'],
        inserter: data['changes'][i]['inserter'],
        wuid: data['changes'][i]['wuid'],
        puid: data['changes'][i]['puid'],
        prouid: data['changes'][i]['prouid'],
        inventory: double.parse(data['changes'][i]['inventory'].toString()),
        backup: 'ok',
      );
      if (!await typeHandle(DataType.WAREHOUSE, 1, warehouse, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.WAREHOUSE);
    }
    // } catch (e) {}
  }

  static getWarehouseS(data) async {
    if (dataHandle(data, 'انبار')) {
      await warehouse.clear();
      for (var i = 0; i < data.length; i++) {
        WarehouseDB wr = WarehouseDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          inserter: data['inserter'],
          wuid: data[i]['wuid'],
          puid: data[i]['puid'],
          prouid: data[i]['prouid'],
          inventory: double.parse(data[i]['inventory'].toString()),
          backup: 'ok',
        );
        await warehouse.add(wr);
      }
    }
  }
  //===========================================================<warehouse name>=================================================================

  static warehouseNameS(type, data) async {
    if (dataHandle(data, 'نام انبار')) {
      var item;
      if (type != 2) {
        item = WarehouseNameDB(
          id: data['id'],
          uid: data['uid'],
          name: data['name'],
          inserter: data['inserter'],
          active: data['active'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.WAREHOUSENAME, type, warehouseName, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.WAREHOUSENAME);
    }
  }

  static getWarehouseNameS(data) async {
    if (dataHandle(data, 'نام انبار')) {
      await warehouseName.clear();
      for (var i = 0; i < data.length; i++) {
        WarehouseNameDB wr = WarehouseNameDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          inserter: data['inserter'],
          name: data[i]['name'],
          active: data[i]['active'],
          backup: 'ok',
        );
        await warehouseName.add(wr);
      }
    }
  }
  //===========================================================<warehouse history>=================================================================

  static warehouseHistoryS(type, data) async {
    if (dataHandle(data, 'تاریخچه')) {
      var item;
      if (type != 2) {
        item = WarehouseHistoryDB(
          id: data['id'],
          uid: data['uid'],
          parentuid: data['parentuid'],
          inserter: data['inserter'],
          from: data['from'],
          to: data['to'],
          date: data['date'] ?? DateTime.now().toIso8601String(),
          by: data['by'].toString(),
          type: data['type'],
          puid: data['puid'],
          prouid: data['prouid'],
          amount: double.parse(data['amount'].toString()),
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.WAREHOUSEHISTORY,
        type,
        warehouseHistory,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.WAREHOUSEHISTORY);
    }
  }

  static getWarehouseHistoryS(data) async {
    if (dataHandle(data, 'تاریخچه')) {
      await warehouseHistory.clear();
      for (var i = 0; i < data.length; i++) {
        WarehouseHistoryDB wr = WarehouseHistoryDB(
          id: data[i]['id'],
          uid: data[i]['uid'],
          parentuid: data[i]['parentuid'],
          inserter: data['inserter'],
          from: data[i]['from'],
          to: data[i]['to'],
          date: data[i]['date'],
          by: data[i]['by'],
          type: data[i]['type'],
          puid: data[i]['puid'],
          prouid: data[i]['prouid'],
          amount: double.parse(data[i]['amount'].toString()),
          backup: 'ok',
        );
        await warehouseHistory.add(wr);
      }
    }
  }

  //===========================================================<connections>=================================================================

  static connectionsS(type, data) async {
    if (dataHandle(data, 'ارتباط')) {
      var item;
      if (type != 2) {
        item = ConnectionDB(
          id: data['id'],
          uid: data['uid'],
          inserter: data['inserter'],
          date: data['date'] ?? DateTime.now().toIso8601String(),
          by: data['by'],
          desc: data['desc'],
          personUID: data['personUID'],
          status: data['status'],
          parent: data['parent'],
          result: data['result'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.CRM, type, connection, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );
      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.CRM);
    }
  }

  static getConnectionsS(data) async {
    await connection.clear();
    for (var i = 0; i < data.length; i++) {
      ConnectionDB item = ConnectionDB(
        id: data[i]['id'],
        uid: data[i]['uid'],
        inserter: data[i]['inserter'],
        date: data[i]['date'] ?? DateTime.now().toIso8601String(),
        by: data[i]['by'],
        desc: data[i]['desc'],
        personUID: data['personUID'],
        status: data[i]['status'],
        parent: data[i]['parent'],
        result: data[i]['result'],
        backup: 'ok',
      );
      await connection.add(item);
    }
  }

  //===========================================================<yar permissions>=================================================================

  static yarPermissionS(type, data) async {
    if (dataHandle(data, 'سطح دسترسی')) {
      var item;
      if (type != 2) {
        item = MiKYarPermissionDB(
          id: data['id'],
          uid: data['uid'],
          name: data['name'],
          permission: data['permission'],
          inserter: data['inserter'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.YARPERMISSION,
        type,
        mikyarPermission,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.YARPERMISSION);
    }
  }

  static getYarPermissionS(data) async {
    if (dataHandle(data, 'سطح دسترسی')) {
      await mikyarPermission.clear();
      try {
        for (var i = 0; i < data.length; i++) {
          MiKYarPermissionDB ch = MiKYarPermissionDB(
            id: data[i]['id'],
            uid: data[i]['uid'],
            name: data[i]['name'],
            permission: data[i]['permission'],
            inserter: data[i]['inserter'],
            backup: 'ok',
          );
          await mikyarPermission.add(ch);
        }
      } catch (e) {}
    }
  }

  //===========================================================<yar permission ext>=================================================================

  static yarPermissionExtS(type, data) async {
    if (dataHandle(data, '')) {
      var item;
      if (type != 2) {
        item = MiKYarPermissionExtDB(
          id: data['id'],
          uid: data['uid'],
          yarID: data['yarID'],
          branch: List<String>.from(data['branch']),
          warehouse: List<String>.from(data['warehouse']),
          inserter: data['inserter'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(
        DataType.YARPERMISSIONEXT,
        type,
        mikyarPermissionExt,
        item,
      ))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.YARPERMISSIONEXT);
    }
  }

  static getYarPermissionExtS(data) async {
    if (dataHandle(data, 'فرد')) {
      await mikyarPermissionExt.clear();
      try {
        for (var i = 0; i < data.length; i++) {
          MiKYarPermissionExtDB ch = MiKYarPermissionExtDB(
            id: data[i]['id'],
            uid: data[i]['uid'],
            yarID: data[i]['yarID'],
            branch: List<String>.from(data[i]['branch']),
            warehouse: List<String>.from(data[i]['warehouse']),
            inserter: data[i]['inserter'],
            backup: 'ok',
          );
          await mikyarPermissionExt.add(ch);
        }
      } catch (e) {}
    }
  }
  //===========================================================<branch>=================================================================

  static branchS(type, data) async {
    if (dataHandle(data, 'شعبه')) {
      var item;
      if (type != 2) {
        item = BranchDB(
          id: data['id'],
          uid: data['uid'],
          name: data['name'],
          active: data['active'],
          description: data['description'],
          address: data['address'],
          location: data['location'],
          inserter: data['inserter'],
          defaultWarehouse: data['defaultWarehouse'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.BRANCH, type, branch, item)) return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.BRANCH);
    }
  }

  static getBranchS(data) async {
    await branch.clear();
    if (dataHandle(data, 'شعبه')) {
      try {
        for (var i = 0; i < data.length; i++) {
          BranchDB ch = BranchDB(
            id: data[i]['id'],
            uid: data[i]['uid'],
            name: data[i]['name'],
            active: data[i]['active'],
            description: data[i]['description'],
            address: data[i]['address'],
            location: data[i]['location'],
            inserter: data[i]['inserter'],
            defaultWarehouse: data[i]['defaultWarehouse'],
            backup: 'ok',
          );
          await branch.add(ch);
        }
      } catch (e) {}
    }
  }
  //===========================================================<branch access>=================================================================

  static branchAccessS(type, data) async {
    if (dataHandle(data, '')) {
      var item;
      if (type != 2) {
        item = BranchAccessDB(
          id: data['id'],
          uid: data['uid'],
          branchUID: data['branchUID'],
          warehouseUID: List<String>.from(data['warehouseUID']),
          inserter: data['inserter'],
          backup: 'ok',
        );
      } else {
        item = data['uid'];
      }
      if (!await typeHandle(DataType.BRANCHACCESS, type, branchAccess, item))
        return;
      await alertHandle(
        item,
        data['appEvent'] ?? 'receive_data',
        data['editor'] ?? '',
      );

      await backHandle(data['isBack'], data['editor'] ?? '');
      await initPage(item, DataType.BRANCHACCESS);
    }
  }

  static getBranchAccessS(data) async {
    if (dataHandle(data, '')) {
      await branchAccess.clear();
      try {
        for (var i = 0; i < data.length; i++) {
          BranchAccessDB ch = BranchAccessDB(
            id: data[i]['id'],
            uid: data[i]['uid'],
            branchUID: data[i]['branchUID'],
            warehouseUID: List<String>.from(data[i]['warehouseUID']),
            inserter: data[i]['inserter'],
            backup: 'ok',
          );
          await branchAccess.add(ch);
        }
      } catch (e) {}
    }
  }
  //===========================================================<ticket>=================================================================

  static ticketS(type, data) {}
  static getTicketS(data) async {}

  //===========================================================<campaign>=================================================================

  static campaignS(type, data) {}
  static getCampaignS(data) async {}
}
