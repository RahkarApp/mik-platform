// ignore_for_file: avoid_function_literals_in_foreach_calls, empty_catches, prefer_typing_uninitialized_variables, type_literal_in_constant_pattern, file_names

import 'dart:developer';

import '../models/models.dart';
import '../source/remote/api.dart';
import 'variable.dart';
import 'fx/pim.dart';
import '../source/remote/models/models.dart';

class SaveHelper {
  /// Server mutations retain their revision, scope and durable retry key.
  static Future<PimResult> savePim(PimFX fx, PimCommand command) =>
      fx.execute(command);

  static addInvoice(invoiceData) async {
    await API.addInvoice(invoiceData);
  }

  static save(data, {int? index, bool saveToServer = true, PimFX? fx}) async {
    if (data is PimCommand) {
      if (!saveToServer || fx == null) {
        throw ArgumentError('PIM saves require a business context and API');
      }
      return savePim(fx, data);
    }
    var res;
    switch (data.runtimeType) {
      case SettingsData:
        if (saveToServer) {
          data.backup = 'edit';
          res = await API.setting(data.toJson());
          if (res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
          }
        }
        await settingsData.putAt(0, data);
        return saveToServer ? res.body : 'ok';
      case SendSmsSetting:
        break;
      case MiKYarDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await mikyar.putAt(index, data);
            if (saveToServer) res = await API.editMikYar(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await mikyar.putAt(index, data);
            if (saveToServer) res = await API.addMikYar(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyar.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await mikyar.add(data);
          if (saveToServer) res = await API.addMikYar(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyar.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case MiKYarPermissionDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await mikyarPermission.putAt(index, data);
            if (saveToServer) {
              res = await API.editMikYarPermission(data.toJson());
            }
          } else if (data.backup == 'new' || data.backup == null) {
            await mikyarPermission.putAt(index, data);
            if (saveToServer) {
              res = await API.addMikYarPermission(data.toJson());
            }
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyarPermission.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await mikyarPermission.add(data);
          if (saveToServer) res = await API.addMikYarPermission(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyarPermission.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case MiKYarPermissionExtDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await mikyarPermissionExt.putAt(index, data);
            if (saveToServer) {
              res = await API.editMikYarPermissionExt(data.toJson());
            }
          } else if (data.backup == 'new' || data.backup == null) {
            await mikyarPermissionExt.putAt(index, data);
            if (saveToServer) {
              res = await API.addMikYarPermissionExt(data.toJson());
            }
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyarPermissionExt.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await mikyarPermissionExt.add(data);
          if (saveToServer) {
            res = await API.addMikYarPermissionExt(data.toJson());
          }

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await mikyarPermissionExt.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case ProfileDB:
        data.backup = saveToServer ? 'edit' : 'ok';
        if (saveToServer) res = await API.updateProfile(data.toJson());
        if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
          data.backup = 'ok';
          data.id = res.body.id;
        }
        await profile.putAt(0, data);
        return saveToServer ? res.body : 'ok';
      case PersonDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await person.putAt(index, data);
            if (saveToServer) res = await API.editPerson(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await person.putAt(index, data);
            if (saveToServer) res = await API.addPerson(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await person.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await person.add(data);
          if (saveToServer) res = await API.addPerson(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await person.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case PartnerTransactionDB:
        if (index != null && index > -1) {
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await partnerTransaction.add(data);
          if (saveToServer) {
            res = await API.addPartnerTransaction(data.toJson());
          }

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await partnerTransaction.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case ProductDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await product.putAt(index, data);
            if (saveToServer) res = await API.editProduct(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await product.putAt(index, data);
            if (saveToServer) res = await API.addProduct(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;

            await product.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await product.add(data);
          if (saveToServer) res = await API.addProduct(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await product.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case CategoryDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await category.putAt(index, data);
            if (saveToServer) res = await API.editCategory(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await category.putAt(index, data);
            if (saveToServer) res = await API.addCategory(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await category.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await category.add(data);
          res = await API.addCategory(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await category.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      // case FactorDB:
      //   if (index != null && index > -1) {
      //     //edit
      //     if (data.backup == 'ok' || data.backup == 'edit') {
      //       data.backup = 'edit';
      //       await factor.putAt(index, data);
      //       res = await API.editInvoice(data.toJson());
      //     }  else if (data.backup == 'new'|| data.backup == null) {
      //       await factor.putAt(index, data);
      //       res = await API.addInvoice(data.toJson());
      //     }
      //     if (res != null && res.statusCode == 200 && res.body == data.toJson()) {
      //       data.backup = 'ok'; data.id = res.body.id;
      //       await factor.putAt(index, data);
      //     }
      //   } else {
      //     //new
      //     if(saveToServer)data.inserter = 0;
      //     data.backup = 'new';
      //     index = await factor.add(data);
      //     res = await API.addInvoice(data.toJson());
      //     if (res != null && res.statusCode == 200 && res.body == data.toJson()) {
      //       data.backup = 'ok'; data.id = res.body.id;
      //       await factor.put(index, data);
      //     }
      //   }
      //   return res.body;
      case CostCategoryDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await costCategory.putAt(index, data);
            if (saveToServer) res = await API.editCostCategory(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await costCategory.putAt(index, data);
            if (saveToServer) res = await API.addCostCategory(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await costCategory.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await costCategory.add(data);
          if (saveToServer) res = await API.addCostCategory(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await costCategory.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case CostDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await cost.putAt(index, data);
            if (saveToServer) res = await API.editCost(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await cost.putAt(index, data);
            if (saveToServer) res = await API.addCost(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await cost.put(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await cost.add(data);
          if (saveToServer) res = await API.addCost(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await cost.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case JWT:
        break;
      case CommissionDB:
        if (index != null && index > -1) {
          // //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await commission.putAt(index, data);
            if (saveToServer) res = await API.editCommission(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await commission.putAt(index, data);
            if (saveToServer) res = await API.addCommission(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await commission.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await commission.add(data);
          if (saveToServer) res = await API.addCommission(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await commission.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case BillDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await bill.putAt(index, data);
            if (saveToServer) res = await API.editBill(data.toJson());
            log(res.body.toString());
          } else if (data.backup == 'new' || data.backup == null) {
            await bill.putAt(index, data);
            if (saveToServer) res = await API.addBill(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await bill.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await bill.add(data);
          if (saveToServer) res = await API.addBill(data.toJson());
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await bill.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case ChequeDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await cheque.putAt(index, data);
            if (saveToServer) res = await API.editCheque(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await cheque.putAt(index, data);
            if (saveToServer) res = await API.addCheque(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await cheque.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await cheque.add(data);
          if (saveToServer) res = await API.addCheque(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await cheque.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case FinancialPeriod:
        if (index != null && index > -1) {
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await financialPeriod.add(data);
          if (saveToServer) res = await API.addfinancialPeriod(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await financialPeriod.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case LocalSetting:
        break;
      case LoginData:
        break;
      case FCM:
        if (index != null && index > -1) {
        } else {
          if (fcm.values.isNotEmpty) await fcm.clear();
          index = await fcm.add(data);
          if (saveToServer) res = await API.addFcmToken(data.toJson());
        }
        return saveToServer ? res.body : 'ok';
      case ConnectionDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await connection.putAt(index, data);
            if (saveToServer) res = await API.crmEditConnection(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await connection.putAt(index, data);
            if (saveToServer) res = await API.crmAddConnection(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await connection.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await connection.add(data);
          if (saveToServer) res = await API.crmAddConnection(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await connection.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case MSG:
        break;
      case PollType:
        break;
      case PatternDB:
        break;
      case SMS:
        //nobackup
        if (index != null && index > -1) {
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          index = await sms.add(data);
          if (saveToServer) res = await API.sendSMS(data.toJson());
        }
        return saveToServer ? res.body : 'ok';
      case SmsPatternValue:
        break;
      case ProductPropertyDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await productProperty.putAt(index, data);
            if (saveToServer) {
              res = await API.editProductProperty(data.toJson());
            }
          } else if (data.backup == 'new' || data.backup == null) {
            await productProperty.putAt(index, data);
            if (saveToServer) res = await API.addProductProperty(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            // data.uid = res.body.uid;
            await productProperty.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          int i = productProperty.values.toList().indexWhere((d) => d.uid == data.uid);
          if (i > -1) {
            await productProperty.putAt(i, data);
          } else {
            index = await productProperty.add(data);
          }
          if (saveToServer) res = await API.addProductProperty(data.toJson());
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            if (i > -1) {
              await productProperty.putAt(i, data);
            } else {
              await productProperty.put(index, data);
            }
          }
        }
        return saveToServer ? res.body : 'ok';
      case ProductProDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await productPro.putAt(index, data);
            if (saveToServer) {
              res = await API.editProductPro(data.toJson());
            }
          } else if (data.backup == 'new' || data.backup == null) {
            await productPro.putAt(index, data);
            if (saveToServer) res = await API.addProductPro(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            // data.id = res.body.id;
            await productPro.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await productPro.add(data);
          if (saveToServer) res = await API.addProductPro(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            // data.id = res.body.id;
            await productPro.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';

      case ProductPriceDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await productPrice.putAt(index, data);
            if (saveToServer) {
              res = await API.editProductPrice(data.toJson());
            }
          } else if (data.backup == 'new' || data.backup == null) {
            await productPrice.putAt(index, data);
            if (saveToServer) res = await API.addProductPrice(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            // data.id = res.body.id;
            await productPrice.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await productPrice.add(data);
          if (saveToServer) res = await API.addProductPrice(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            // data.id = res.body.id;
            await productPrice.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';

      case BranchDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await branch.putAt(index, data);
            if (saveToServer) res = await API.editBranch(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await branch.putAt(index, data);
            if (saveToServer) res = await API.addBranch(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await branch.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await branch.add(data);
          if (saveToServer) res = await API.addBranch(data.toJson());
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await branch.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case BranchAccessDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await branchAccess.putAt(index, data);
            if (saveToServer) res = await API.editBranchAccess(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await branchAccess.putAt(index, data);
            if (saveToServer) res = await API.addBranchAccess(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await branchAccess.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await branchAccess.add(data);
          if (saveToServer) res = await API.addBranchAccess(data.toJson());
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await branchAccess.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case WarehouseDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await warehouse.putAt(index, data);
            if (saveToServer) res = await API.editWarehouse(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await warehouse.putAt(index, data);
            if (saveToServer) res = await API.addWarehouse(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await warehouse.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await warehouse.add(data);
          if (saveToServer) {
            res = await API.addWarehouse(data.toJson());
            if (res != null && res.statusCode == 200 && res.body == data.toJson()) {
              data.backup = 'ok';
              data.id = res.body.id;
              await warehouse.put(index, data);
            }
          }
        }
        return saveToServer ? res.body : 'ok';
      case WarehouseHistoryDB:
        if (index != null && index > -1) {
          //edit
          // if (data.backup == 'ok' || data.backup == 'edit') {
          //   data.backup = 'edit';
          //   await warehouseHistory.putAt(index, data);
          //   res = await API.editWarehouseHistory(data.toJson());
          // }  else if (data.backup == 'new'|| data.backup == null) {
          //   await warehouseHistory.putAt(index, data);
          //   res = await API.addWarehouseHistory(data.toJson());
          // }
          // if (res != null && res.statusCode == 200 && res.body == data.toJson()) {
          //   data.backup = 'ok'; data.id = res.body.id;
          //   await warehouseHistory.putAt(index, data);
          // }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await warehouseHistory.add(data);
          if (saveToServer) res = await API.addWarehouseHistory(data.toJson());
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await warehouseHistory.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';

      case WarehouseNameDB:
        if (index != null && index > -1) {
          //edit
          if (data.backup == 'ok' || data.backup == 'edit') {
            data.backup = saveToServer ? 'edit' : 'ok';
            await warehouseName.putAt(index, data);
            if (saveToServer) res = await API.editWarehouseName(data.toJson());
          } else if (data.backup == 'new' || data.backup == null) {
            await warehouseName.putAt(index, data);
            if (saveToServer) res = await API.addWarehouseName(data.toJson());
          }
          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await warehouseName.putAt(index, data);
          }
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          data.backup = saveToServer ? 'new' : 'ok';
          index = await warehouseName.add(data);
          if (saveToServer) res = await API.addWarehouseName(data.toJson());

          if (saveToServer && res != null && res.statusCode == 200 && res.body == data.toJson()) {
            data.backup = 'ok';
            data.id = res.body.id;
            await warehouseName.put(index, data);
          }
        }
        return saveToServer ? res.body : 'ok';
      case ProductDraftDB:
        //nobackup - local only storage
        if (index != null && index > -1) {
          //edit
          await productDraft.putAt(index, data);
        } else {
          //new
          index = await productDraft.add(data);
        }
        return 'ok';
      case TemporaryProduct:
        //nobackup
        if (index != null && index > -1) {
          //edit
          await temporaryProduct.putAt(index, data);
        } else {
          //new
          if (saveToServer) data.inserter = 0;
          index = await temporaryProduct.add(data);
        }
        return '200';
      default:
    }
  }

  static delete(data, index) async {
    // try {
    //   data.backup = false;
    // } catch (e) {
    //   return;
    // }
    var res;
    switch (data.runtimeType) {
      case SettingsData:
        break;
      case SendSmsSetting:
        break;
      case ProfileDB:
        break;
      case PersonDB:
        break;
      case ConnectionDB:
        res = await API.crmDeleteConnection(data.toJson());
        await connection.deleteAt(index);
      case PartnerTransactionDB:
        res = await API.delPartnerTransaction(data.toJson());
        await partnerTransaction.deleteAt(index);
      case ProductDB:
        res = await API.delProduct(data.toJson());
        await product.deleteAt(index);
      case CategoryDB:
        res = await API.delCategory(data.toJson());
      case MiKYarPermissionDB:
        res = await API.delMikYarPermission(data.toJson());
        await mikyarPermission.deleteAt(index);

      case MiKYarDB:
        res = await API.delMikYar(data.toJson());
        await mikyar.deleteAt(index);
      case BranchDB:
        res = await API.delBranch(data.toJson());
        await branch.deleteAt(index);
      case BranchAccessDB:
        res = await API.delBranchAccess(data.toJson());
        await branchAccess.deleteAt(index);
      case InvoiceDB:
        res = await API.delInvoice(data.toJson());
        await invoice.deleteAt(index);
      case CostCategoryDB:
        res = await API.delCostCategory(data.toJson());
        await costCategory.deleteAt(index);
      case CostDB:
        res = await API.delCost(data.toJson());
      //await cost.deleteAt(index);
      //break;
      case WarehouseDB:
        res = await API.delWarehouse(data.toJson());
        await warehouse.deleteAt(index);
      case WarehouseNameDB:
        await warehouseName.deleteAt(index);
        res = await API.delWarehouseName(data.toJson());
      case WarehouseHistoryDB:
        res = await API.delWarehouseHistory(data.toJson());
        await warehouseHistory.deleteAt(index);

      case ChequeDB:
        res = await API.delCheque(data.toJson());
        await cheque.deleteAt(index);
      case JWT:
        break;
      case CommissionDB:
        break;
      case BillDB:
        res = await API.delBill(data.toJson());
        await bill.deleteAt(index);
      case FinancialPeriod:
        break;
      case LocalSetting:
        break;
      case LoginData:
        break;
      case FCM:
        break;
      case MSG:
        break;
      case PollType:
        break;
      case PatternDB:
        res = await API.deletePattern(data.code);
        await pattern.deleteAt(index);
      case SMS:
        break;
      case SmsPatternValue:
        break;
      case ProductPropertyDB:
        res = await API.delProductProperty(data.toJson());
        await productProperty.deleteAt(index);
      case ProductProDB:
        res = await API.delProductPro(data.toJson());
        await productPro.deleteAt(index);
      case ProductPriceDB:
        res = await API.delProductPrice(data.toJson());
        await productPrice.deleteAt(index);
      case ProductDraftDB:
        //nobackup - local only
        await productDraft.deleteAt(index);
        return 'ok';
      case TemporaryProduct:
        break;
      default:
    }
    if (res != null && res != '400' && res != 400) {
      return '200';
    } else {
      await dataToServer.add(DataToServer(data: data, type: 'delete'));
      return '400';
    }
  }

  static reSend() async {
    var res;
    try {
      var st = settingsData.getAt(0)!;
      if (st.backup != 'ok') {
        var res = await API.setting(st.toJson());
        if (res != null && res.statusCode == 200 && res.body == st.toJson()) {
          st.backup = 'ok';
          await settingsData.putAt(0, st);
        }
      }
    } catch (e) {}
    try {
      var pr = profile.getAt(0)!;
      if (pr.backup != 'ok') {
        res = await API.updateProfile(pr.toJson());
        if (res != null && res.statusCode == 200 && res.body == pr.toJson()) {
          pr.backup = 'ok';
          await profile.putAt(0, pr);
        }
      }
    } catch (e) {}
    try {
      var rp = person.values.where((element) => element.backup != 'ok').toList();
      if (rp.isNotEmpty) {
        //print('new Person Find');
        rp.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editPerson(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addPerson(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = person.values.toList().indexOf(p);
            p.backup = 'ok';
            await person.putAt(i, p);
          }
        });
      }
    } catch (e) {
      return;
    }
    try {
      var rpa = partnerTransaction.values.where((element) => element.backup != 'ok').toList();
      //print(rpa);
      if (rpa.isNotEmpty) {
        rpa.forEach((p) async {
          if (p.backup == 'new') {
            res = await API.addPartnerTransaction(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = partnerTransaction.values.toList().indexOf(p);
            p.backup = 'ok';
            await partnerTransaction.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rc = category.values.where((element) => element.backup != 'ok').toList();
      //print(rc);
      if (rc.isNotEmpty) {
        rc.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editCategory(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addCategory(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = category.values.toList().indexOf(p);
            p.backup = 'ok';
            await category.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rpr = product.values.where((element) => element.backup != 'ok').toList();
      //print(rpr);
      if (rpr.isNotEmpty) {
        rpr.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editProduct(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addProduct(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = product.values.toList().indexOf(p);
            p.backup = 'ok';
            await product.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rpr = productPrice.values.where((element) => element.backup != 'ok').toList();
      //print(rpr);
      if (rpr.isNotEmpty) {
        rpr.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editProductPrice(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addProductPrice(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = productPrice.values.toList().indexOf(p);
            p.backup = 'ok';
            await productPrice.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rpr = productPro.values.where((element) => element.backup != 'ok').toList();
      //print(rpr);
      if (rpr.isNotEmpty) {
        rpr.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editProductPro(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addProductPro(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = productPro.values.toList().indexOf(p);
            p.backup = 'ok';
            await productPro.putAt(i, p);
          }
        });
      }
    } catch (e) {}

    try {
      var rpr = productProperty.values.where((element) => element.backup != 'ok').toList();
      //print(rpr);
      if (rpr.isNotEmpty) {
        rpr.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editProductProperty(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addProductProperty(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = productProperty.values.toList().indexOf(p);
            p.backup = 'ok';
            await productProperty.putAt(i, p);
          }
        });
      }
    } catch (e) {}

    // try {
    //   var rf =
    //       factor.values.where((element) => element.backup != 'ok').toList();
    //   //print(rf);
    //   if (rf.isNotEmpty) {
    //     rf.forEach((p) async {
    //       if (p.backup == 'edit') {
    //         res = await API.editInvoice(p.toJson());
    //       } else if (p.backup == 'new') {
    //         res = await API.addInvoice(p.toJson());
    //       }
    //       if (res != null &&
    //           res.statusCode == 200 &&
    //           (res.body == p.toJson() || res.body == 'exist')) {
    //         int i = factor.values.toList().indexOf(p);
    //         p.backup = 'ok';
    //         await factor.putAt(i, p);
    //       }
    //     });
    //   }
    // } catch (e) {}
    try {
      var rcom = commission.values.where((element) => element.backup != 'ok').toList();
      //print(rcom);
      if (rcom.isNotEmpty) {
        rcom.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editCommission(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addCommission(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = commission.values.toList().indexOf(p);
            p.backup = 'ok';
            await commission.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rccat = costCategory.values.where((element) => element.backup != 'ok').toList();
      //print(rccat);
      if (rccat.isNotEmpty) {
        rccat.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editCostCategory(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addCostCategory(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = costCategory.values.toList().indexOf(p);
            p.backup = 'ok';
            await costCategory.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rcc = cost.values.where((element) => element.backup != 'ok').toList();
      //print(rcc);
      if (rcc.isNotEmpty) {
        rcc.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editCost(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addCost(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = cost.values.toList().indexOf(p);
            p.backup = 'ok';
            await cost.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rb = bill.values.where((element) => element.backup != 'ok').toList();
      //print(rb);
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editBill(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addBill(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = bill.values.toList().indexOf(p);
            p.backup = 'ok';
            await bill.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    try {
      var rb = cheque.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editCheque(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addCheque(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = cheque.values.toList().indexOf(p);
            p.backup = 'ok';
            await cheque.putAt(i, p);
          }
        });
      }
    } catch (e) {}

    //==========
    try {
      var rb = warehouse.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editWarehouse(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addWarehouse(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = warehouse.values.toList().indexOf(p);
            p.backup = 'ok';
            await warehouse.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    //==========
    try {
      var rb = warehouseName.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editWarehouseName(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addWarehouseName(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = warehouseName.values.toList().indexOf(p);
            p.backup = 'ok';
            await warehouseName.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    //==========
    try {
      var rb = warehouseHistory.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editWarehouseHistory(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addWarehouseHistory(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = warehouseHistory.values.toList().indexOf(p);
            p.backup = 'ok';
            await warehouseHistory.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    //==========
    try {
      var rb = branch.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editBranch(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addBranch(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = branch.values.toList().indexOf(p);
            p.backup = 'ok';
            await branch.putAt(i, p);
          }
        });
      }
    } catch (e) {}
    //==========
    try {
      var rb = branchAccess.values.where((element) => element.backup != 'ok').toList();
      if (rb.isNotEmpty) {
        rb.forEach((p) async {
          if (p.backup == 'edit') {
            res = await API.editBranchAccess(p.toJson());
          } else if (p.backup == 'new') {
            res = await API.addBranchAccess(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = branchAccess.values.toList().indexOf(p);
            p.backup = 'ok';
            await branchAccess.putAt(i, p);
          }
        });
      }
    } catch (e) {}

    //===============
    try {
      var rfp = financialPeriod.values.where((element) => element.backup != 'ok').toList();
      //print(rfp);
      if (rfp.isNotEmpty) {
        rfp.forEach((p) async {
          if (p.backup == 'new') {
            res = await API.addfinancialPeriod(p.toJson());
          }
          if (res != null && res.statusCode == 200 && (res.body == p.toJson() || res.body == 'exist')) {
            int i = financialPeriod.values.toList().indexOf(p);
            p.backup = 'ok';
            await financialPeriod.putAt(i, p);
          }
        });
      }
      // productPreoperty;
      // propertyInventory;
    } catch (e) {}

    try {
      for (var i = 0; i < dataToServer.length; i++) {
        var d = dataToServer.getAt(i)!;
        if (d.type == 'delete') {
          await delete(dataToServer.getAt(i)!, 0);
        } else if (d.type == 'pic') {
          var r = await API.sendFile(d.data, agin: true);
          if (r != null && r == '200') {
            await dataToServer.deleteAt(i);
          }
        }
      }
    } catch (e) {}

    try {
      await API.sendDataQueue();
    } catch (e) {}
  }
}
