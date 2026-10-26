import 'package:mik_data/utils/fx/business_context.dart';
// ignore_for_file: library_prefixes, avoid_print

import 'dart:developer';

import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_variables/variable.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../../../utils/fx/warehouse.dart';
import '../../../utils/variable.dart';
import 'socket_controller.dart';

class SKT {
  static void Function(dynamic data)? onWooConnected;
  static final socket = IO.io(
    'wss://app.mikcore.ir',
    IO.OptionBuilder()
        .setTransports(['websocket']) // استفاده از WebSocket
        //.disableAutoConnect()
        .enableForceNew()
        .enableReconnection() // اجازه تلاش خودکار برای اتصال مجدد
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(10000)
        .setReconnectionAttempts(0) // بی‌نهایت تلاش
        .setAuth({'token': jwt.getAt(0)!.token.toString(), 'app': 'mik'})
        .build(),
  );
  static retryConnection() async {
    if (BusinessContext.forApp('mik') != null) return;
    while (socketConnected.value == 'error') {
      print('Trying to reconnect...');

      socket.connect(); // تلاش مجدد برای اتصال
      // منتظر بمانید تا اتصال برقرار شود یا تلاش دوباره کنید
      await Future.delayed(const Duration(seconds: 5));
    }
    print('Reconnected to server');
  }

  static Future<void> emit(
    String event,
    data,
    String appEvent, {
    bool? isBack,
  }) async {
    if (internetCheck.isTrue) {
      if (socketConnected.value == 'ok' || socketConnected.value == 'fresh') {
        waitServer.value = true;
        var dataMap = data.toJson();
        dataMap['appEvent'] = appEvent;
        dataMap['isBack'] = isBack ?? false;
        var myData = dataMap;

        socket.emit(event, myData);
      } else {
        Alert.error('به سرور متصل نیستید');
      }
    } else {
      Alert.error('شما به اینترنت متصل نیستید، انترنت خود را چک کنید');
    }
  }

  static connect() async {
    if (BusinessContext.forApp('mik') != null) return;
    print('ejraye connect');
    try {
      socket.connect();
    } catch (e) {}

    socket.onConnect((_) async {
      socketConnected.value = 'fresh';
      await Future.delayed(const Duration(seconds: 3));
      socketConnected.value = 'ok';
      log('=========================================================');
      log('connect');
      log('=========================================================');
    });
    socket.onConnectError((data) async {
      if (socketConnected.value == 'ok') {
        Alert.error('خطا در اتصال به سرور');
        socketConnected.value = 'error';
      }

      socket.disconnect();
      // await retryConnection();

      log("=========================================================");
      log("error is : $data");
      log("=========================================================");
    });

    socket.onReconnect((_) {
      log("=========================================================");
      log("sever reconnect");
      log("=========================================================");
    });

    socket.onReconnectAttempt((_) {
      log("=========================================================");
      log("sever reconnectAttempt");
      log("=========================================================");
    });

    socket.onDisconnect((data) async {
      if (socketConnected.value == 'ok') {
        socketConnected.value = 'error';
        Alert.error('سرویس دریافت همزمان اطلاعات قطع شد');
      }
      if (socketConnected.value != 'disconnect') await retryConnection();
    });

    // socket.on('permission', (data) {
    //   // print('permissions is = $data');
    //   SocketController.permissionS(data);
    // });

    // socket.on//onAny((e, d) {
    //   log("=========================   SOCKET EVENT   ================================");
    //   log(e.toString());
    //   log(d.toString());
    //   log("========================= END SOCKET EVENT ==============================");
    // });
    socket.on('woo_connected', (data) {
      onWooConnected?.call(data);
    });

    socket.on('get_setting', (data) {
      log(data.toString());
    });
    socket.on('lastData', (data) {
      SocketController.lastData(data);
    });

    //======================================<product>=======================================================

    socket.on('create_product', (data) {
      SocketController.productS(0, data);
    });

    socket.on('get_product', (data) {
      SocketController.getProductS(data);
    });

    socket.on('edit_product', (data) {
      SocketController.productS(1, data);
    });

    socket.on('delete_product', (data) {
      SocketController.productS(2, data);
    });

    socket.on('create_productPro', (data) {
      SocketController.productProS(0, data);
    });

    socket.on('get_productPro', (data) {
      SocketController.getProductProS(data);
    });

    socket.on('edit_productPro', (data) {
      SocketController.productProS(1, data);
    });

    socket.on('delete_productPro', (data) {
      SocketController.productProS(2, data);
    });

    socket.on('create_productPrice', (data) {
      SocketController.productPriceS(0, data);
    });

    socket.on('get_productPrice', (data) {
      SocketController.getProductPriceS(data);
    });

    socket.on('edit_productPrice', (data) {
      SocketController.productPriceS(1, data);
    });

    socket.on('delete_productPrice', (data) {
      SocketController.productPriceS(2, data);
    });

    socket.on('create_productProperty', (data) {
      SocketController.productPropertyS(0, data);
    });

    socket.on('get_productProperty', (data) {
      SocketController.getProductPropertyS(data);
    });

    socket.on('edit_productProperty', (data) {
      SocketController.productPropertyS(1, data);
    });

    socket.on('delete_productProperty', (data) {
      SocketController.productPropertyS(2, data);
    });
    //======================================<bill>=======================================================

    socket.on('create_bill', (data) {
      SocketController.billS(0, data);
    });

    socket.on('get_bill', (data) {
      SocketController.getBillS(data);
    });

    socket.on('edit_bill', (data) {
      SocketController.billS(1, data);
    });

    socket.on('delete_bill', (data) {
      SocketController.billS(2, data);
    });
    //======================================<Branch>=======================================================

    socket.on('create_branch', (data) {
      SocketController.branchS(0, data);
    });

    socket.on('get_branch', (data) {
      SocketController.getBranchS(data);
    });

    socket.on('edit_branch', (data) {
      SocketController.branchS(1, data);
    });

    socket.on('delete_branch', (data) {
      SocketController.branchS(2, data);
    });
    //======================================<Branch Access>=======================================================

    socket.on('create_branchAccess', (data) {
      SocketController.branchAccessS(0, data);
    });

    socket.on('get_branchAccess', (data) {
      SocketController.getBranchAccessS(data);
    });

    socket.on('edit_branchAccess', (data) {
      SocketController.branchAccessS(1, data);
    });

    socket.on('delete_branchAccess', (data) {
      SocketController.branchAccessS(2, data);
    });

    //======================================<cheque>=======================================================

    socket.on('create_cheque', (data) {
      SocketController.chequeS(0, data);
    });

    socket.on('get_cheque', (data) {
      SocketController.getChequeS(data);
    });

    socket.on('edit_cheque', (data) {
      SocketController.chequeS(1, data);
    });

    socket.on('delete_cheque', (data) {
      SocketController.chequeS(2, data);
    });

    //======================================<ticket>=======================================================

    socket.on('create_ticket', (data) {
      SocketController.ticketS(0, data);
    });

    socket.on('get_ticket', (data) {
      SocketController.getTicketS(data);
    });

    socket.on('edit_ticket', (data) {
      SocketController.ticketS(1, data);
    });

    socket.on('delete_ticket', (data) {
      SocketController.ticketS(2, data);
    });

    //======================================<campaign>=======================================================

    socket.on('create_campaign', (data) {
      SocketController.campaignS(0, data);
    });

    socket.on('get_campaign', (data) {
      SocketController.getCampaignS(data);
    });

    socket.on('edit_campaign', (data) {
      SocketController.campaignS(1, data);
    });

    socket.on('delete_campaign', (data) {
      SocketController.campaignS(2, data);
    });

    //======================================<category>=======================================================

    socket.on('create_category', (data) {
      SocketController.categoryS(0, data);
    });

    socket.on('get_category', (data) {
      SocketController.getCategoryS(data);
    });

    socket.on('edit_category', (data) {
      SocketController.categoryS(1, data);
    });

    socket.on('delete_category', (data) {
      SocketController.categoryS(2, data);
    });

    //======================================<CRM>=======================================================

    socket.on('create_CRM', (data) {
      SocketController.connectionsS(0, data);
    });

    socket.on('get_CRM', (data) {
      SocketController.getConnectionsS(data);
    });

    socket.on('edit_CRM', (data) {
      SocketController.connectionsS(0, data);
    });

    socket.on('delete_CRM', (data) {
      SocketController.connectionsS(0, data);
    });

    //======================================<investment>=======================================================

    socket.on('create_investment', (data) {
      SocketController.partnerTransactionS(0, data);
    });

    socket.on('get_investment', (data) {
      SocketController.getPartnerTransactionS(data);
    });

    socket.on('edit_investment', (data) {
      SocketController.partnerTransactionS(0, data);
    });

    socket.on('delete_investment', (data) {
      SocketController.partnerTransactionS(0, data);
    });

    //======================================<commission>=======================================================

    socket.on('create_commission', (data) {
      SocketController.commissionS(0, data);
    });

    socket.on('get_commission', (data) {
      SocketController.getCommissionS(data);
    });

    socket.on('edit_commission', (data) {
      SocketController.commissionS(1, data);
    });

    socket.on('delete_commission', (data) {
      SocketController.commissionS(2, data);
    });

    //======================================<cost>=======================================================

    socket.on('create_cost', (data) {
      SocketController.costS(0, data);
    });

    socket.on('get_cost', (data) {
      SocketController.getCostS(data);
    });

    socket.on('edit_cost', (data) {
      SocketController.costS(1, data);
    });

    socket.on('delete_cost', (data) {
      SocketController.costS(2, data);
    });

    //======================================<cost_category>=======================================================

    socket.on('create_costCategory', (data) {
      SocketController.costCategoryS(0, data);
    });

    socket.on('get_costCategory', (data) {
      SocketController.getCostCategory(data);
    });

    socket.on('edit_costCategory', (data) {
      SocketController.costCategoryS(1, data);
    });

    socket.on('delete_costCategory', (data) {
      SocketController.costCategoryS(2, data);
    });

    //======================================<user>=======================================================

    socket.on('create_user', (data) {
      SocketController.userS(0, data);
    });

    socket.on('get_user', (data) {
      SocketController.getUserS(data);
    });

    socket.on('edit_user', (data) {
      SocketController.userS(1, data);
    });

    socket.on('delete_user', (data) {
      SocketController.userS(2, data);
    });
    //======================================<yar user>=======================================================

    socket.on('create_yaruser', (data) {
      SocketController.yarUserS(0, data);
    });

    socket.on('get_yaruser', (data) {
      SocketController.getYarUserS(data);
    });

    socket.on('edit_yaruser', (data) {
      SocketController.yarUserS(1, data);
    });

    socket.on('delete_yaruser', (data) {
      SocketController.yarUserS(2, data);
    });
    //======================================<yar user permission>=======================================================

    socket.on('create_yarpermission', (data) {
      SocketController.yarPermissionS(0, data);
    });

    socket.on('get_yarpermission', (data) {
      SocketController.getYarPermissionS(data);
    });

    socket.on('edit_yarpermission', (data) {
      SocketController.yarPermissionS(1, data);
    });

    socket.on('delete_yarpermission', (data) {
      SocketController.yarPermissionS(2, data);
    });
    //======================================<yar user permissionEXT>=======================================================

    socket.on('create_yarpermissionext', (data) {
      SocketController.yarPermissionExtS(0, data);
    });

    socket.on('get_yarpermissionext', (data) {
      SocketController.getYarPermissionExtS(data);
    });

    socket.on('edit_yarpermissionext', (data) {
      SocketController.yarPermissionExtS(1, data);
    });

    socket.on('delete_yarpermissionext', (data) {
      SocketController.yarPermissionExtS(2, data);
    });

    //======================================<partner transaction>=======================================================

    socket.on('create_partnertransaction', (data) {
      SocketController.partnerTransactionS(0, data);
    });

    socket.on('get_partnertransaction', (data) {
      SocketController.getPartnerTransactionS(data);
    });

    socket.on('edit_partnertransaction', (data) {
      SocketController.partnerTransactionS(1, data);
    });

    socket.on('delete_partnertransaction', (data) {
      SocketController.partnerTransactionS(2, data);
    });
    //======================================<Warehouse>=======================================================

    socket.on('create_warehouse', (data) {
      SocketController.warehouseS(0, data);
    });

    socket.on('get_warehouse', (data) {
      SocketController.getWarehouseS(data);
    });

    socket.on('edit_warehouse', (data) {
      SocketController.warehouseS(1, data);
    });

    socket.on('edit_warehouse_bulk', (data) {
      SocketController.warehouseEditBulk(data);
    });

    socket.on('delete_warehouse', (data) {
      SocketController.warehouseS(2, data);
    });

    //======================================<Warehouse History>=======================================================

    socket.on('create_warehouseHistory', (data) {
      SocketController.warehouseHistoryS(0, data);
    });

    socket.on('get_warehouseHistory', (data) {
      SocketController.getWarehouseHistoryS(data);
    });

    socket.on('edit_warehouseHistory', (data) {
      SocketController.warehouseHistoryS(1, data);
    });

    socket.on('delete_warehouseHistory', (data) {
      SocketController.warehouseHistoryS(2, data);
    });

    //======================================<Warehouse Name>=======================================================

    socket.on('create_warehouseName', (data) {
      SocketController.warehouseNameS(0, data);
    });
    socket.on('get_warehouseName', (data) {
      SocketController.getWarehouseNameS(data);
    });
    socket.on('edit_warehouseName', (data) {
      SocketController.warehouseNameS(1, data);
    });
    socket.on('delete_warehouseName', (data) {
      SocketController.warehouseNameS(2, data);
    });

    //======================================<Setting>=======================================================

    socket.on('update_setting', (data) {
      SocketController.settingsS(1, data);
    });
    socket.on('get_setting', (data) {
      SocketController.getSettingS(data);
    });

    //======================================<Invoice>=======================================================

    socket.on('create_invoice', (data) async {
      log('===============\ndata:\n$data\n=========================');
      if (SocketController.dataHandle(data, 'فاکتور')) {
        await SocketController.invoiceS(0, data['invoice']);
        for (var i = 0; i < data['bill'].length; i++) {
          await SocketController.billS(0, data['bill'][i]);
        }

        for (var i = 0; i < data['cheque'].length; i++) {
          await SocketController.chequeS(0, data['cheque'][i]);
        }

        for (var i = 0; i < data['warehouseHistory'].length; i++) {
          await SocketController.warehouseHistoryS(
            0,
            data['warehouseHistory'][i],
          );
        }
        // if (data['invoice']['status'] != 900) {
        //   WarehouseFX.IW(
        //     saveToServer: false,
        //     invoiceUID: data['invoice']['uuid'].toString(),
        //     warehouseUID: List<String>.from(data['warehouse']),
        //     puid: List<String>.from(data['invoice']['productUID']),
        //     propertyUID: List<String>.from(
        //         data['invoice']['productUID'].map((e) => '').toList()),
        //     amount: List<double>.from(
        //         data['invoice']['amount'].map((e) => e.toDouble())),
        //     type: data['invoice']['isBuy'] ? 'I2W' : 'W2I',
        //   );
        // }
      }
    });

    socket.on('get_invoice', (data) {
      SocketController.getInvoiceS(data);
    });

    socket.on('edit_invoice', (data) async {
      log('\n\nEDIT INVOICE:\n');
      log(data.toString());
      if (SocketController.dataHandle(data, 'فاکتور')) {
        await SocketController.invoiceS(1, data['invoice']);
        for (var i = 0; i < data['bill'].length; i++) {
          await SocketController.billS(1, data['bill'][i]);
        }

        await WarehouseFX.deleteHistory(
          List<String>.from(data['warehouseHistoryDeleteUID']),
        );

        //back inventory
        // if (data['warehouseHistoryBackAmount'].isNotEmpty) {
        //   var d = data['warehouseHistoryBackAmount']
        //       .map((e) => e.toDouble())
        //       .toList();
        //   WarehouseFX.IW(
        //       invoiceUID: data['invoice']['uuid'].toString(),
        //       warehouseUID: List<String>.from(data['warehouse']),
        //       puid: List<String>.from(data['invoice']['productUID']),
        //       propertyUID: List<String>.from(
        //           data['invoice']['productUID'].map((e) => '-').toList()),
        //       amount: List<double>.from(d),
        //       type: !data['invoice']['isBuy'] ? 'I2W' : 'W2I',
        //       saveToServer: false);
        // }

        for (var i = 0; i < data['warehouseHistory'].length; i++) {
          await SocketController.warehouseHistoryS(
            1,
            data['warehouseHistory'][i],
          );
        }
        // if (data['warehouseHistoryBackAmount'].isNotEmpty &&
        //     data['invoice']['status'] != 8 &&
        //     data['invoice']['status'] != 9 &&
        //     data['invoice']['status'] != 444 &&
        //     data['invoice']['status'] != 900 &&
        //     data['invoice']['status'] != 901) {
        //   WarehouseFX.IW(
        //       invoiceUID: data['invoice']['uuid'].toString(),
        //       warehouseUID: List<String>.from(data['warehouse']),
        //       puid: List<String>.from(data['invoice']['productUID']),
        //       propertyUID: List<String>.from(
        //           data['invoice']['productUID'].map((e) => '-').toList()),
        //       amount: List<double>.from(
        //           data['invoice']['amount'].map((e) => e.toDouble())),
        //       type: data['invoice']['isBuy'] ? 'I2W' : 'W2I',
        //       saveToServer: false);۵
        // }
      }
    });

    socket.on('delete_invoice', (data) {
      SocketController.invoiceS(2, data);
    });

    socket.on('create_invoiceHistory', (data) {
      SocketController.invoiceHistoryS(0, data);
    });

    //======================================<Pattern>=======================================================

    socket.on('create_pattern', (data) {
      SocketController.patternS(0, data);
    });
    socket.on('get_pattern', (data) {
      SocketController.getPatternS(data);
    });
    socket.on('edit_pattern', (data) {
      SocketController.patternS(1, data);
    });
    socket.on('delete_pattern', (data) {
      SocketController.patternS(2, data);
    });

    socket.on('create_person', (data) {
      SocketController.personS(0, data);
    });
    socket.on('get_person', (data) {
      SocketController.getPersonS(data);
    });
    socket.on('edit_person', (data) {
      SocketController.personS(1, data);
    });
    socket.on('delete_person', (data) {
      SocketController.personS(2, data);
    });
  }

  static disconnect() {
    if (BusinessContext.forApp('mik') != null) return;
    // socketConnected.value = 'disconnect';
    socket.disconnect();

    // socket!.onDisconnect((_) => print('disconnect'));
  }

  static checkStatus() {}
}
