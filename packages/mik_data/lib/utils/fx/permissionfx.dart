import 'package:mik_variables/permissions.dart';

import 'package:mik_components/elements/titledList.dart';
import 'package:mik_data/models/models.dart';
import 'package:mik_data/utils/variable.dart';
import 'package:mik_variables/variable.dart';

class PermissionFx {
  static bool hasPermission(String name) => PermissionAccess.hasPermission(name);

  static String findPermission(MiKYarDB my) {
    final direct = my.permission ?? '';
    if (direct.isNotEmpty) return direct;
    for (final role in mikyarPermission.values) {
      if (my.permissionUID != null && my.permissionUID!.isNotEmpty &&
          my.permissionUID == role.uid) return role.permission ?? '';
    }
    return '';
  }

  static String encode(List<int> values) => values.map((v) => v == 1 ? '1' : '0').join();
  static String code(List<int> values) => encode(values);

  static List<int> decode(String stored) =>
      PermissionCatalog.encodeLegacy(PermissionCatalog.decode(stored), original: stored)
          .split('').map(int.parse).toList();

  static int length(String cpr) {
    return decode(cpr).length;
  }

  static int accept(String stored) => PermissionCatalog.decode(stored).length;

  static bool isShowInvoiceMenu() {
    return PermissionAccess.hasAny([
      PermissionsName.invoicesBuyView, PermissionsName.invoicesBuyViewAll,
      PermissionsName.invoicesSellView, PermissionsName.invoicesSellViewAll,
      PermissionsName.invoicesPreView, PermissionsName.invoicesPreViewAll,
    ]);
  }

 static bool isAddSell() {
   
    if(PermissionAccess.hasPermission(PermissionsName.invoicesSellCreate) ){
      return true;
    }
    return false;
  }

   static bool isAddBuy() {
   
    if(PermissionAccess.hasPermission(PermissionsName.invoicesBuyCreate) ){
      return true;
    }
    return false;
  }

  static bool isAddCost() {

    if(PermissionAccess.hasPermission(PermissionsName.costsCreate) ){
      return true;
    }
    return false;
  }

   static bool isShowCostItem(CostDB costItem) {
   
    if(PermissionAccess.hasPermission(PermissionsName.costsViewAll) ||(PermissionAccess.hasPermission(PermissionsName.costsView) && costItem.inserter == mikyarProfileID)){
      return true;
    }
    return false;
  }

  static bool isShowShippingCostItem(InvoiceDB invoiceItem) {
   
    if(PermissionAccess.hasPermission(PermissionsName.costsShippingViewAll) ||(PermissionAccess.hasPermission(PermissionsName.costsShippingView) && invoiceItem.inserter == mikyarProfileID)){
      return true;
    }
    return false;
  }

  static bool isShowChequeItem(ChequeDB item) => PermissionAccess.canAccessRecord(
      own: PermissionsName.chequesView, all: PermissionsName.chequesViewAll,
      inserter: item.inserter);

  static bool isShowBillItem(Map billItem) {
   
    bool flag = false;
      if (billItem['toUID']!.startsWith('F')) {
        //خرید
        if (billItem['debtorUID'] == '' || billItem['debtorUID'] == '-') {
          if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyViewAll) ||
              (PermissionAccess.hasPermission(PermissionsName.invoicesBuyView) && billItem['inserter'] == mikyarProfileID)) {
            flag = true;
           
          }
        } else {
          if (PermissionAccess.hasPermission(PermissionsName.invoicesSellViewAll) ||
              (PermissionAccess.hasPermission(PermissionsName.invoicesSellView) && billItem['inserter'] == mikyarProfileID)) {
            flag = true;
          }
        }
      } else {
        if (PermissionAccess.hasPermission(PermissionsName.costsViewAll) ||
            (PermissionAccess.hasPermission(PermissionsName.costsView) && billItem['inserter'] == mikyarProfileID)) {
          flag = true;
        }
      }
    

    return flag;
  }

  static bool isShowFactorItem(InvoiceDB factorItem) {
    if (factorItem.billUID!.isEmpty) {
      if (PermissionAccess.hasPermission(PermissionsName.invoicesPreViewAll) ||
          (PermissionAccess.hasPermission(PermissionsName.invoicesPreView) && factorItem.inserter == mikyarProfileID)) {
        return true;
      }
    } else if (factorItem.type == 'buy') {
      if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyViewAll) ||
          (PermissionAccess.hasPermission(PermissionsName.invoicesBuyView) && factorItem.inserter == mikyarProfileID)) {
        return true;
      }
    } else if (!(factorItem.type == 'buy')) {
      if (PermissionAccess.hasPermission(PermissionsName.invoicesSellViewAll) ||
          (PermissionAccess.hasPermission(PermissionsName.invoicesSellView) && factorItem.inserter == mikyarProfileID)) {
        return true;
      }
    }

    return false;
  }

  

  static bool isShowPinndedHeader(type, List items) {
    for (int i = 0; i < items.length; i++) {
      switch (type) {
        case const (TitledListType.factor):
          if (items[i].billUID!.isEmpty) {
            if (PermissionAccess.hasPermission(PermissionsName.invoicesPreViewAll) ||
                (PermissionAccess.hasPermission(PermissionsName.invoicesPreView) &&
                    items[i].inserter == mikyarProfileID)) {
              return true;
            }
          } else if (items[i].isBuy!) {
            if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyViewAll) ||
                (PermissionAccess.hasPermission(PermissionsName.invoicesBuyView) &&
                    items[i].inserter == mikyarProfileID)) {
              return true;
            }
          } else if (!items[i].isBuy!) {
            if (PermissionAccess.hasPermission(PermissionsName.invoicesSellViewAll) ||
                (PermissionAccess.hasPermission(PermissionsName.invoicesSellView) &&
                    items[i].inserter == mikyarProfileID)) {
              return true;
            }
          }
          break;
        case const (TitledListType.cost):
          if (PermissionAccess.hasPermission(PermissionsName.costsViewAll) ||
              (items[i].inserter == mikyarProfileID && PermissionAccess.hasPermission(PermissionsName.costsView))) {
            return true;
          }
          break;

        case (TitledListType.shippingCost):
          if (PermissionAccess.hasPermission(PermissionsName.costsShippingViewAll) ||
              (items[i].inserter == mikyarProfileID && PermissionAccess.hasPermission(PermissionsName.costsShippingView))) {
            return true;
          }
        case (TitledListType.cheque):
          if (PermissionAccess.hasPermission(PermissionsName.chequesViewAll) ||
              (items[i].inserter == mikyarProfileID && PermissionAccess.hasPermission(PermissionsName.chequesView))) {
            return true;
          }
        case (TitledListType.bill):
          bool flag = false;
          items[i]['billItem'].forEach((billItem) {
            if (billItem.toUID!.startsWith('F')) {
              //خرید
              if (billItem.debtorUID == '' || billItem.debtorUID == '-') {
                if (PermissionAccess.hasPermission(PermissionsName.invoicesBuyViewAll) ||
                    (PermissionAccess.hasPermission(PermissionsName.invoicesBuyView) &&
                        billItem.inserter == mikyarProfileID)) {
                  flag = true;
                }
              } else {
                if (PermissionAccess.hasPermission(PermissionsName.invoicesSellViewAll) ||
                    (PermissionAccess.hasPermission(PermissionsName.invoicesSellView) &&
                        billItem.inserter == mikyarProfileID)) {
                  flag = true;
                }
              }
            } else {
              if (PermissionAccess.hasPermission(PermissionsName.costsViewAll) ||
                  (PermissionAccess.hasPermission(PermissionsName.costsView) &&
                      billItem.inserter == mikyarProfileID)) {
                flag = true;
              }
            }
          });

          return flag;
      }
    }

    return false;
  }

  static bool isShowPersonItem(PersonDB personItem) {
    if (personItem.isSupplier!) {
      if (PermissionAccess.hasPermission(PermissionsName.suppliersViewAll) ||
          (PermissionAccess.hasPermission(PermissionsName.suppliersView) && personItem.inserter == mikyarProfileID)) {
        return true;
      }
    } else if (personItem.isService!) {
      if (PermissionAccess.hasPermission(PermissionsName.servicersViewAll) ||
          (PermissionAccess.hasPermission(PermissionsName.servicersView) && personItem.inserter == mikyarProfileID)) {
        return true;
      }
    }
    return false;
  }

  static bool isAddCRM( ) {
   
    if(PermissionAccess.hasPermission(PermissionsName.crmCreate) ){
      return true;
    }
    return false;
  }

  static bool isShowConnection(ConnectionDB connectionItem) {
    
      if (PermissionAccess.hasPermission(PermissionsName.crmViewAll) || (PermissionAccess.hasPermission(PermissionsName.crmView) && connectionItem.inserter == mikyarProfileID)) {
        return true;
      }
    
    return false;
  
}
}
