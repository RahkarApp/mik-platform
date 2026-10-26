// ignore_for_file: empty_catches, file_names, prefer_typing_uninitialized_variables

import 'package:hive/hive.dart';
import 'package:mik_utils/private/smsSystem.dart';
import 'package:mik_utils/public/findID.dart';
import 'package:mik_variables/variable.dart';

import '../models/models.dart';
import '../source/remote/api.dart';
import 'saveHelper.dart';
import 'variable.dart';

class RXData {
  static data(data) async {
    for (var i = 0; i < data.length; i++) {
      switch (data[i]['type'].toString().split('-')[0]) {
        case 'patternActive':
          for (var j = 0; j < pattern.length; j++) {
            var hasPT = pattern.getAt(j)!;
            if (hasPT.code == data[i]['data']['code'] && hasPT.orderType == data[i]['data']['orderType']) {
              hasPT.status = 'active';
              await pattern.putAt(i, hasPT);
              settingsData = await Hive.openBox<SettingsData>('settings');
              settings = settingsData.getAt(0)!;
              await SMSSystem.changeAutoSMS(data[i]['data']['orderType'], true);
              try {
                //    SmartNotifPage().initPage();
              } catch (e) {}
              break;
            }
          }
          break;
        case 'onlinePay':
          var thisbill = bill.values.where((element) => element.toUID == '' ? element.to == data[i]['data']['to'] : element.toUID == data[i]['data']['toUID']).toList();
          var totalPaid = 0;
          for (var b = 0; b < thisbill.length; b++) {
            totalPaid = totalPaid + thisbill[b].paid!.toInt();
          }
          BillDB billItem = BillDB(
            id: (ID.endId(bill)).toString().startsWith('10000') ? int.parse((ID.endId(bill)).toString().substring(4)) + 1 : ID.newId(bill),
            uid: data[i]['data']['uid'],
            debtor: data[i]['data']['debtor'],
            creditor: data[i]['data']['creditor'],
            debtorUID: data[i]['data']['debtorUID'],
            creditorUID: data[i]['data']['creditorUID'],
            total: data[i]['data']['total'],
            paid: data[i]['data']['paid'],
            unPaid: data[i]['data']['total'] - data[i]['data']['paid'] - totalPaid,
            to: data[i]['data']['to'],
            toUID: data[i]['data']['toUID'],
            date: data[i]['data']['date'].toString().replaceAll('Z', ''),
            deadLine: data[i]['data']['deadLine'].toString().replaceAll('Z', ''),
            inserter: data[i]['data']['inserter'],
            meta: data[i]['data']['meta'],
            type: 'online',
          );
          await SaveHelper.save(billItem);
          // await bill.add(billItem);
          // API.editBillID(billItem.toJson(), data[i]['data']['id']);
          // addSmartPayCommission(billItem.id, billItem.to, billItem.paid,
          //     billItem.date, data[i]['type']);
          if (data[i]['data']['toUID'] == '' ? data[i]['data']['to'].toString().startsWith('f') : data[i]['data']['toUID'].toString().startsWith('F-')) {
            int fID = data[i]['data']['toUID'] == '' ? int.parse(data[i]['data']['to'].toString().replaceAll('f', '')) : 0;
            var thisFactor;
            int index = -1;
            for (var i = 0; i < invoice.length; i++) {
              var element = invoice.getAt(i);
              if (data[i]['data']['toUID'] == '' ? element!.id == fID : element!.uid == data[i]['data']['toUID'].toString().replaceAll('F-', '')) {
                thisFactor = element;
                index = i;
              }
            }
            thisFactor.billUID!.add(billItem.uid);
            await SaveHelper.save(thisFactor, index: index);
            // await factor.putAt(index, thisFactor);
            // API.editFactor(thisFactor.toJson());
          }
          break;
        case 'newPerson':
          PersonDB pr = PersonDB(
            id: data[i]['data']['id'],
            uid: data[i]['data']['uid'],
            date: data[i]['data']['date'],
            name: data[i]['data']['name'],
            nationalID: data[i]['data']['nationalID'],
            mobile: data[i]['data']['mobile'],
            instagram: data[i]['data']['instagram'],
            email: data[i]['data']['email'],
            cardNumber: data[i]['data']['cardNumber'],
            shebaNumber: data[i]['data']['shebaNumber'],
            address: data[i]['data']['address'],
            isAdmin: data[i]['data']['isAdmin'],
            isSupplier: data[i]['data']['isSupplier'],
            isPartner: data[i]['data']['isPartner'],
            isCustomer: data[i]['data']['isCustomer'],
            isMarketer: data[i]['data']['isMarketer'],
            isService: data[i]['data']['isService'],
            description: data[i]['data']['description'],
            stateID: data[i]['data']['stateID'],
            townID: data[i]['data']['townID'],
            org: data[i]['data']['org'],
            orgName: data[i]['data']['orgName'],
            tel: data[i]['data']['tel'],
            economicID: data[i]['data']['economicID'],
            postalCode: data[i]['data']['postalCode'],
            inserter: data[i]['data']['inserter'],
          );
          List exist = person.values.where((element) => element.uid == pr.uid).toList();
          if (exist.isEmpty) await person.add(pr);
          break;
        case 'editPerson':
          int prIndex = person.values.toList().indexWhere((element) => element.uid == data[i]['data']['uid']);
          var pr = person.getAt(prIndex)!;
          pr.name = data[i]['data']['name'];
          pr.instagram = data[i]['data']['instagram'];
          pr.address = data[i]['data']['address'];
          pr.cardNumber = data[i]['data']['cardNumber'];
          await person.putAt(prIndex, pr);
          break;
        case 'smartFactor':
          InvoiceDB inv = InvoiceDB(
            id: data[i]['data']['id'] ?? 0,
            uid: data[i]['data']['uid'],
            personUID: data[i]['data']['personUID'],
            branchUID: data[i]['data']['branchUID'],
            items: data[i]['data']['items'],
            billUID: data[i]['data']['billUID'],
            date: data[i]['data']['date'],
            doc: data[i]['data']['doc'],
            parameters: data[i]['data']['parameters'],
            type: data[i]['data']['type'],
            shipping: data[i]['data']['shipping'],
            status: data[i]['data']['status'],
            commission: data[i]['data']['commission'],
            description: data[i]['data']['description'],
            inserter: data[i]['data']['inserter'],
            backup: 'ok',
          );
          await invoice.add(inv);
          List exist = invoice.values.where((element) => element.uid == inv.uid).toList();
          if (exist.isEmpty) await invoice.add(inv);
          break;
        case 'smartPay':
          var fct;
          BillDB billItem = BillDB(
            id: data[i]['data']['id'],
            uid: data[i]['data']['uid'],
            debtor: data[i]['data']['debtor'],
            creditor: 0,
            debtorUID: data[i]['data']['debtorUID'],
            creditorUID: '',
            total: data[i]['data']['total'],
            paid: data[i]['data']['paid'],
            unPaid: data[i]['data']['unPaid'],
            to: data[i]['data']['to'],
            toUID: data[i]['data']['toUID'],
            date: data[i]['data']['date'],
            deadLine: data[i]['data']['deadLine'],
            inserter: data[i]['data']['inserter'],
            meta: data[i]['data']['meta'],
            type: 'smart',
          );
          List exist = bill.values.where((element) => element.uid == billItem.uid).toList();
          if (exist.isEmpty) {
            await bill.add(billItem);
            for (var i = 0; i < invoice.length; i++) {
              if (('F-${invoice.getAt(i)!.uid}') == billItem.toUID && !invoice.getAt(i)!.billUID!.contains(billItem.uid)) {
                fct = invoice.getAt(i)!;
                fct.billUID!.add(billItem.uid);
                await invoice.putAt(i, fct);
                break;
              }
            }
          }
          if (data[i]['type'].toString().split('-').length > 1 && data[i]['type'].toString().split('-')[1] == 'paid') {
            for (var i = 0; i < fct.productID.length; i++) {
              int prIndex = product.values.toList().indexWhere((element) => element.uid == fct.productUID[i]);
              var pr = product.getAt(prIndex)!;
              pr.inventory = pr.inventory! - fct.amount[i];
              await product.putAt(prIndex, pr);
            }
          }
          // if (data[i]['data']['paid'] > 0)
          // addSmartPayCommission(billItem.id, billItem.to, billItem.paid,
          //     billItem.date, data[i]['type']);
          break;
        default:
      }
      API.dataQuOK({'id': data[i]['_id']});
    }
  }

  static stage(stage) async {
    var msgListID = [];
    msg = await Hive.openBox<MSG>('msg');
    for (var element in msg.values) {
      msgListID.add(element.id);
    }
    for (var i = 0; i < stage['msg'].length; i++) {
      var stageMSG = stage['msg'][i];
      if (!msgListID.contains(stageMSG['id'])) {
        var mt = await API.getMSGbyID(stageMSG['id']);
        var m;
        if (!mt['hasError']) m = mt['data'];
        var fileName = '';
        var fileType = '';
        try {
          fileName = m['file']['name'];
          fileType = m['file']['fileType'];
        } catch (e) {}
        PollType pollType = PollType(type: m['pollType']['type'], options: m['pollType']['options']);
        MSG newMsg = MSG(
          title: m['title'],
          msg: m['msg'],
          fileName: fileName,
          fileType: fileType,
          link: m['link'],
          read: false,
          date: m['date'],
          type: m['type'],
          id: m['_id'],
          isPoll: m['isPoll'],
          pollType: pollType,
          poll: '',
        );
        await msg.add(newMsg);
        msgCount.value++;
      }
    }
  }
}
