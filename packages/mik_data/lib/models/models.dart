import 'package:mik_consts/permission_names.dart';
// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class SettingsData {
  @HiveField(0)
  String? darkMode;
  @HiveField(1)
  int? dayForCancel;
  @HiveField(2)
  bool? animation;
  @HiveField(3)
  int? factorType;
  @HiveField(4)
  String? factorText;
  @HiveField(5)
  String? factorColor1;
  @HiveField(6)
  String? factorColor2;
  @HiveField(7)
  SendSmsSetting? sendSms;
  @HiveField(8)
  bool? skipInit;
  @HiveField(9, defaultValue: 'new')
  String? backup;
  @HiveField(10, defaultValue: 7)
  int? dayForPreFactor;
  @HiveField(11, defaultValue: false)
  bool? usePreFactor;
  @HiveField(12, defaultValue: false)
  bool? factorVat;
  @HiveField(13, defaultValue: false)
  bool? factorLink;
  @HiveField(14, defaultValue: 'a4')
  String? factorSize;
  @HiveField(15, defaultValue: false)
  bool? factorIsRial;
  @HiveField(16)
  List<String>? connectionStatus;
  @HiveField(17, defaultValue: 'FIFO')
  String? profitInInvoice;

  SettingsData({
    this.darkMode,
    this.dayForCancel,
    this.animation,
    this.factorType,
    this.factorText,
    this.factorColor1,
    this.factorColor2,
    this.sendSms,
    this.skipInit,
    this.backup,
    required this.dayForPreFactor,
    required this.usePreFactor,
    required this.factorVat,
    required this.factorLink,
    required this.factorSize,
    required this.factorIsRial,
    this.connectionStatus,
    this.profitInInvoice,
  });

  Map toJson() => {
    'darkMode': darkMode,
    'dayForCancel': dayForCancel,
    'animation': animation,
    'factorType': factorType,
    'factorText': factorText,
    'factorColor1': factorColor1,
    'factorColor2': factorColor2,
    'sendSms': sendSms,
    'skipInit': skipInit,
    'backup': backup,
    'dayForPreFactor': dayForPreFactor,
    'usePreFactor': usePreFactor,
    'factorVat': factorVat,
    'factorLink': factorLink,
    'factorSize': factorSize,
    'factorIsRial': factorIsRial,
    'connectionStatus': connectionStatus,
    'profitInInvoice': profitInInvoice,
  };
}

@HiveType(typeId: 90)
class SendSmsSetting {
  @HiveField(0)
  bool? orderSubmit;
  @HiveField(1)
  bool? orderReadySend;
  @HiveField(2)
  bool? orderSended;
  @HiveField(3)
  bool? orderCancelled;
  @HiveField(4)
  bool? orderReturned;
  @HiveField(5)
  bool? orderDelayTanks;
  @HiveField(6)
  bool? orderOnlinePay;
  @HiveField(7)
  bool? preFactor;

  SendSmsSetting({this.orderSubmit, this.orderSended, this.orderReadySend, this.orderCancelled, this.orderDelayTanks, this.orderReturned, this.orderOnlinePay, required this.preFactor});
  Map toJson() => {
    'orderSubmit': orderSubmit,
    'orderReadySend': orderReadySend,
    'orderSended': orderSended,
    'orderCancelled': orderCancelled,
    'orderReturned': orderReturned,
    'orderDelayTanks': orderDelayTanks,
    'orderOnlinePay': orderOnlinePay,
    'preFactor': preFactor,
  };
}

@HiveType(typeId: 1)
class ProfileDB {
  @HiveField(0)
  String? name;
  @HiveField(1)
  String? img;
  @HiveField(2)
  String? date;
  @HiveField(3)
  List? cardNumber;
  @HiveField(4)
  List? shebaNumber;
  @HiveField(5)
  List? cardNumberName;
  @HiveField(6)
  String? province;
  @HiveField(7)
  String? city;
  @HiveField(8)
  String? email;
  @HiveField(9)
  List? tel;
  @HiveField(10)
  int? id;
  @HiveField(11)
  String? instagram;
  @HiveField(12)
  String? site;
  @HiveField(13)
  String? slogan;
  @HiveField(14)
  String? referral;
  @HiveField(15)
  int? stateID;
  @HiveField(16)
  int? townID;
  @HiveField(17)
  String? address;
  @HiveField(18)
  String? economicCode;
  @HiveField(19)
  String? mobile;
  @HiveField(20)
  List? type;
  @HiveField(21, defaultValue: 'new')
  String? backup;
  @HiveField(22, defaultValue: '')
  String? nationalID;
  @HiveField(23, defaultValue: '')
  String? postalCode;
  @HiveField(24, defaultValue: false)
  bool? tspEnabled;

  ProfileDB({
    this.id,
    this.name,
    this.img,
    this.date,
    this.cardNumber,
    this.shebaNumber,
    this.cardNumberName,
    this.province,
    this.city,
    this.email,
    this.tel,
    this.instagram,
    this.site,
    this.slogan,
    this.referral,
    this.stateID,
    this.townID,
    this.address,
    this.economicCode,
    required this.mobile,
    required this.type,
    required this.postalCode,
    this.backup,
    this.nationalID,
    this.tspEnabled,
  });

  Map toJson() => {
    'id': id,
    'name': name,
    'img': img,
    'date': date,
    'cardNumber': cardNumber,
    'shebaNumber': shebaNumber,
    'cardNumberName': cardNumberName,
    'province': province,
    'city': city,
    'email': email,
    'tel': tel,
    'instagram': instagram,
    'site': site,
    'slogan': slogan,
    'referral': referral,
    'stateID': stateID,
    'townID': townID,
    'address': address,
    'economicCode': economicCode,
    'mobile': mobile,
    'type': type,
    'backup': backup,
    'nationalID': nationalID,
    'postalCode': postalCode,
    'tspEnabled': tspEnabled,
  };
}

@HiveType(typeId: 2)
class PersonDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? date;
  @HiveField(2)
  String? name;
  @HiveField(3)
  String? nationalID;
  @HiveField(4)
  String? mobile;
  @HiveField(5)
  String? instagram;
  @HiveField(6)
  String? email;
  @HiveField(7)
  String? cardNumber;
  @HiveField(8)
  String? shebaNumber;
  @HiveField(9)
  String? address;
  @HiveField(10)
  bool? isAdmin;
  @HiveField(11)
  bool? isSupplier;
  @HiveField(12)
  bool? isPartner;
  @HiveField(13)
  bool? isCustomer;
  @HiveField(14)
  bool? isMarketer;
  @HiveField(15)
  bool? isService;
  @HiveField(16)
  String? description;
  @HiveField(17)
  int? stateID;
  @HiveField(18)
  int? townID;
  @HiveField(19, defaultValue: 'new')
  String? backup;
  @HiveField(20)
  String? orgName;
  @HiveField(21, defaultValue: false)
  bool? org;
  @HiveField(22)
  String? tel;
  @HiveField(23)
  String? economicID;
  @HiveField(24)
  String? postalCode;
  @HiveField(25, defaultValue: 0)
  int? inserter;
  @HiveField(26, defaultValue: '')
  String? uid;

  PersonDB({
    this.id,
    required this.uid,
    this.date,
    this.name,
    this.nationalID,
    this.mobile,
    this.instagram,
    this.email,
    this.cardNumber,
    this.shebaNumber,
    this.address,
    this.isAdmin,
    this.isSupplier,
    this.isPartner,
    this.isCustomer,
    this.isMarketer,
    this.isService,
    this.description,
    this.stateID,
    this.townID,
    this.backup,
    this.orgName,
    this.org,
    this.tel,
    this.economicID,
    this.postalCode,
    required this.inserter,
  });

  Map toJson() => {
    'id': id,
    'uid': uid,
    'date': date,
    'name': name,
    'nationalID': nationalID,
    'mobile': mobile,
    'instagram': instagram,
    'email': email,
    'cardNumber': cardNumber,
    'shebaNumber': shebaNumber,
    'address': address,
    'isAdmin': isAdmin,
    'isSupplier': isSupplier,
    'isPartner': isPartner,
    'isCustomer': isCustomer,
    'isMarketer': isMarketer,
    'isService': isService,
    'decription': description,
    'stateID': stateID,
    'townID': townID,
    'backup': backup,
    'orgName': orgName,
    'org': org,
    'tel': tel,
    'economicID': economicID,
    'postalCode': postalCode,
    'inserter': inserter,
  };
}

@HiveType(typeId: 3)
class PartnerTransactionDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  int? partnerID;
  @HiveField(2)
  int? amount;
  @HiveField(3)
  String? status; //invest - withdrawal - profit
  @HiveField(4)
  String? date;
  @HiveField(5)
  String? description;
  @HiveField(6, defaultValue: 'new')
  String? backup;
  @HiveField(7, defaultValue: 0)
  int? inserter;
  @HiveField(8, defaultValue: '')
  String? uid;
  @HiveField(9)
  String? partnerUID;

  PartnerTransactionDB({this.id, required this.uid, this.partnerID, this.amount, this.status, this.date, this.description, this.backup, required this.inserter, required this.partnerUID});

  Map toJson() => {
    'id': id,
    'uid': uid,
    'partnerID': partnerID,
    'amount': amount,
    'status': status,
    'date': date,
    'description': description,
    'backup': backup,
    'inserter': inserter,
    'partnerUID': partnerUID,
  };
}

@HiveType(typeId: 4)
class ProductDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? name;
  @HiveField(2)
  List? img;
  @HiveField(3)
  int? categoryID;
  @HiveField(4)
  String? barcode;
  @HiveField(5)
  String? description;
  @HiveField(6)
  int? sellPrice;
  @HiveField(7)
  num? commission;
  @HiveField(8)
  bool? isCommissionFixed;
  @HiveField(9)
  String? date;
  @HiveField(10)
  bool? archive;
  @HiveField(12)
  double? inventory; //amount count
  @HiveField(13)
  String? inventoryControl; //normal //peroperty
  @HiveField(14)
  String? type; //product //service //make
  @HiveField(15)
  List? peropertyID;
  @HiveField(16, defaultValue: 'new')
  String? backup;
  @HiveField(17, defaultValue: 0.0)
  double? vat;
  @HiveField(18, defaultValue: [])
  List<int>? sellPriceList;
  @HiveField(19, defaultValue: 0)
  int? unitCode;
  @HiveField(20)
  List<String>? catIDList;
  @HiveField(21, defaultValue: 0)
  int? inserter;
  @HiveField(22, defaultValue: '')
  String? uid;
  @HiveField(23, defaultValue: '')
  String? taxID;

  ProductDB({
    this.id,
    required this.uid,
    this.taxID,
    this.name,
    this.img,
    this.categoryID,
    this.barcode,
    this.description,
    this.sellPrice,
    this.commission,
    this.isCommissionFixed,
    this.date,
    this.archive,
    this.inventory,
    this.inventoryControl,
    this.type,
    this.peropertyID,
    this.backup,
    this.vat,
    this.sellPriceList,
    this.unitCode,
    this.catIDList,
    required this.inserter,
  });

  Map toJson() => {
    'id': id,
    'uid': uid,
    'taxID': taxID,
    'name': name,
    'img': img,
    'categoryID': categoryID,
    'barcode': barcode,
    'description': description,
    'sellPrice': sellPrice,
    'commission': commission,
    'isCommissionFixed': isCommissionFixed,
    'date': date,
    'archive': archive,
    'inventory': inventory,
    'inventoryControl': inventoryControl,
    'type': type,
    'peropertyID': peropertyID,
    'backup': backup,
    'vat': vat,
    'sellPriceList': sellPriceList,
    'unitCode': unitCode,
    'catIDList': catIDList,
    'inserter': inserter,
  };
}

@HiveType(typeId: 5)
class CategoryDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? name;
  @HiveField(2)
  String? description;
  @HiveField(3)
  String? type;
  @HiveField(4, defaultValue: 'new')
  String? backup;
  @HiveField(5, defaultValue: 0)
  int? inserter;
  @HiveField(6, defaultValue: '')
  String? uid;
  @HiveField(7, defaultValue: '')
  String? parent;
  @HiveField(8, defaultValue: true)
  bool isActive;
  @HiveField(9, defaultValue: false)
  bool isCustom;

  CategoryDB({this.id, required this.uid, this.name, required this.parent, this.description, this.type, this.backup, required this.inserter, this.isActive = true, this.isCustom = false});

  Map toJson() => {'id': id, 'uid': uid, 'name': name, 'parent': parent, 'description': description, 'type': type, 'backup': backup, 'inserter': inserter, 'isActive': isActive, 'isCustom': isCustom};
}

@HiveType(typeId: 6)
class FactorDB {
  @HiveField(0)
  int? id; //
  @HiveField(1)
  List? productID; //[{id: ,property:[{property: '' detail:''},{...}]}]
  @HiveField(2)
  List? amount;
  @HiveField(3)
  List? buyPrice;
  @HiveField(4)
  List? sellPrice; //
  @HiveField(5)
  String? date; //
  @HiveField(6)
  int? personID;
  @HiveField(7)
  String? doc; //
  @HiveField(8)
  bool? isBuy; //
  @HiveField(9)
  int? excess; //
  @HiveField(10)
  int? shippingCost; //
  @HiveField(11)
  int? status; //==> 0: submit | 1: Ready to send |‌ 2: Posted | 8: cancel | 9:reject
  @HiveField(12)
  String? statusDate; //
  @HiveField(13)
  int? commission; //
  @HiveField(14)
  int? cRecipient; //
  @HiveField(15)
  int? cStatus; //==> 0: Unassigned | 1: Cash withdrawal | 2: Add to investment
  @HiveField(16)
  num? discount; //
  @HiveField(17)
  bool? isDiscountFixed; //
  @HiveField(18)
  String? description; //
  @HiveField(19)
  String? editDate; //
  @HiveField(20)
  List? billID;
  @HiveField(21)
  String? uuid; //
  @HiveField(22)
  String? trakingCode; //
  @HiveField(23)
  String? shippingCompany; //
  @HiveField(24)
  String? type;

  ///
  @HiveField(25, defaultValue: 'new')
  String? backup; //
  @HiveField(26, defaultValue: true)
  bool? vatCalculated; //
  @HiveField(27)
  List? vat; //
  @HiveField(28, defaultValue: 0)
  int? inserter;
  @HiveField(29)
  List<String>? billUID; //
  @HiveField(30)
  List? productUID; //
  @HiveField(31)
  String? cRecipientUID; //
  @HiveField(32)
  String? personUID;
  @HiveField(33)
  Object? items; //{puid:[{prouid:xxxx,price:xxx,buyPrice:xxx,amount:xxx}],...}

  FactorDB({
    this.id,
    this.productID,
    this.amount,
    this.buyPrice,
    this.sellPrice,
    this.date,
    this.personID,
    this.doc,
    this.isBuy,
    this.shippingCost,
    this.status,
    this.statusDate,
    this.commission,
    this.cRecipient,
    this.cStatus,
    this.discount,
    this.isDiscountFixed,
    this.description,
    this.excess,
    this.editDate,
    this.billID,
    this.billUID,
    this.uuid,
    this.trakingCode,
    this.shippingCompany,
    this.type,
    this.backup,
    required this.vatCalculated,
    required this.vat,
    required this.inserter,
    required this.cRecipientUID,
    required this.productUID,
    required this.personUID,
  });

  Map toJson() => {
    'id': id,
    'productID': productID,
    'amount': amount,
    'buyPrice': buyPrice,
    'sellPrice': sellPrice,
    'date': date,
    'personID': personID,
    'doc': doc,
    'isBuy': isBuy,
    'shippingCost': shippingCost,
    'status': status,
    'statusDate': statusDate,
    'commission': commission,
    'cRecipient': cRecipient,
    'cRecipientUID': cRecipientUID,
    'cStatus': cStatus,
    'discount': discount,
    'isDiscountFixed': isDiscountFixed,
    'description': description,
    'excess': excess,
    'editDate': editDate,
    'billID': billID,
    'billUID': billUID,
    'uuid': uuid,
    'trakingCode': trakingCode,
    'shippingCompany': shippingCompany,
    'type': type,
    'backup': backup,
    'vatCalculated': vatCalculated,
    'vat': vat,
    'inserter': inserter,
    'productUID': productUID,
    'personUID': personUID,
  };
}

@HiveType(typeId: 7)
class CostCategoryDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? name;
  @HiveField(2)
  String? description;
  @HiveField(3, defaultValue: 'new')
  String? backup;
  @HiveField(4, defaultValue: 0)
  int? inserter;
  @HiveField(5, defaultValue: '')
  String? uid;

  CostCategoryDB({this.id, required this.uid, this.name, this.description, this.backup, required this.inserter});
  Map toJson() => {'id': id, 'uid': uid, 'name': name, 'description': description, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 8)
class CostDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  int? categoryID;
  @HiveField(2)
  String? name;
  @HiveField(3)
  String? description;
  @HiveField(4)
  int? price;
  @HiveField(5)
  int? factorID;
  @HiveField(6)
  int? personID;
  @HiveField(7)
  String? date;
  @HiveField(8)
  List? billID;
  @HiveField(9, defaultValue: 'new')
  String? backup;
  @HiveField(10, defaultValue: 0)
  int? inserter;
  @HiveField(11, defaultValue: '')
  String? uid;
  @HiveField(12)
  List? billUID;
  @HiveField(13)
  String? categoryUID;
  @HiveField(14)
  String? factorUID;
  @HiveField(15)
  String? personUID;

  CostDB({
    this.id,
    required this.uid,
    this.categoryID,
    required this.categoryUID,
    this.name,
    this.description,
    this.price,
    this.factorID,
    this.personID,
    required this.factorUID,
    required this.personUID,
    this.date,
    this.billID,
    required this.billUID,
    this.backup,
    required this.inserter,
  });

  Map toJson() => {
    'id': id,
    'uid': uid,
    'categoryID': categoryID,
    'categoryUID': categoryUID,
    'name': name,
    'description': description,
    'price': price,
    'factorID': factorID,
    'factorUID': factorUID,
    'personID': personID,
    'personUID': personUID,
    'date': date,
    'billID': billID,
    'billUID': billUID,
    'backup': backup,
    'inserter': inserter,
  };
}

@HiveType(typeId: 9)
class JWT {
  @HiveField(0)
  String? token;
  JWT({this.token});
}

@HiveType(typeId: 10)
class DataQueue {
  @HiveField(0)
  var data;
  @HiveField(1)
  String? url;
  DataQueue({this.data, this.url});
  Map toJson() => {'data': data, "url": url};
}

@HiveType(typeId: 100)
class DataToServer {
  @HiveField(0)
  var data;
  @HiveField(1)
  String? type;

  DataToServer({required this.data, required this.type});
  Map toJson() => {'data': data, 'type': type};
}

@HiveType(typeId: 11)
class CommissionDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  int? personID;
  @HiveField(2)
  int? factorID;
  @HiveField(3)
  int? amount;
  @HiveField(4)
  String? type;
  @HiveField(5)
  String? date;
  @HiveField(6)
  String? description;
  @HiveField(7, defaultValue: 'new')
  String? backup;
  @HiveField(8, defaultValue: 0)
  int? inserter;
  @HiveField(9, defaultValue: '')
  String? uid;
  @HiveField(10)
  String? factorUID;

  CommissionDB({this.id, required this.uid, this.personID, this.factorID, required this.factorUID, this.amount, this.type, this.date, this.description, this.backup, required this.inserter});

  Map toJson() => {
    'id': id,
    'uid': uid,
    'personID': personID,
    'factorID': factorID,
    'factorUID': factorUID,
    'amount': amount,
    'type': type,
    'date': date,
    'description': description,
    'backup': backup,
    'inserter': inserter,
  };
}

@HiveType(typeId: 12)
class BillDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  int? debtor;
  @HiveField(2)
  int? creditor;
  @HiveField(3)
  num? total;
  @HiveField(4)
  num? paid;
  @HiveField(5)
  num? unPaid;
  @HiveField(6)
  String? to;
  @HiveField(7)
  String? date;
  @HiveField(8)
  String? deadLine;
  @HiveField(9)
  String? type;
  @HiveField(10, defaultValue: 'new')
  String? backup;
  @HiveField(11, defaultValue: 0)
  int? inserter;
  @HiveField(12, defaultValue: '')
  String? uid;
  @HiveField(13, defaultValue: '')
  String? toUID;
  @HiveField(14)
  String? debtorUID;
  @HiveField(15)
  String? creditorUID;
  @HiveField(16, defaultValue: {})
  Map? meta;

  BillDB({
    this.id,
    required this.uid,
    this.debtor,
    this.creditor,
    this.total,
    this.paid,
    this.unPaid,
    this.to,
    required this.toUID,
    this.date,
    this.deadLine,
    this.type,
    this.backup,
    required this.inserter,
    required this.debtorUID,
    required this.creditorUID,
    this.meta,
  });
  Map toJson() => {
    'id': id,
    'uid': uid,
    'debtor': debtor,
    'creditor': creditor,
    'total': total,
    'paid': paid,
    'unPaid': unPaid,
    'to': to,
    'toUID': toUID,
    'date': date,
    'deadLine': deadLine,
    'type': type,
    'backup': backup,
    'inserter': inserter,
    'debtorUID': debtorUID,
    'creditorUID': creditorUID,
    'meta': meta,
  };
}

@HiveType(typeId: 13)
class FinancialPeriod {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? startDate;
  @HiveField(2)
  String? endDate;
  @HiveField(3)
  List? partnerID;
  @HiveField(4)
  List? percentage;
  @HiveField(5)
  num? profit;
  @HiveField(6)
  String? date;
  @HiveField(7, defaultValue: 'new')
  String? backup;
  @HiveField(8, defaultValue: 0)
  int? inserter;
  @HiveField(9, defaultValue: '')
  String? uid;

  FinancialPeriod({this.id, required this.uid, this.startDate, this.endDate, this.partnerID, this.percentage, this.profit, this.date, this.backup, required this.inserter});
  Map toJson() => {
    'id': id,
    'uid': uid,
    'startDate': startDate,
    'endDate': endDate,
    'partnerID': partnerID,
    'percentage': percentage,
    'profit': profit,
    'date': date,
    'backup': backup,
    'inserter': inserter,
  };
}

@HiveType(typeId: 14)
class LocalSetting {
  @HiveField(0)
  bool? isLock;
  @HiveField(1)
  String? password;
  @HiveField(2)
  bool? active;
  @HiveField(3)
  bool? init;
  @HiveField(4)
  bool? ipgStatus;
  @HiveField(5)
  int? timeLeft;
  @HiveField(6)
  String? dateupdate;
  @HiveField(7)
  bool? smartLink;
  @HiveField(8)
  List? pageIntro;
  @HiveField(9)
  bool? smartConnect;
  @HiveField(10)
  bool? smartView;
  @HiveField(11, defaultValue: 'new')
  String? backup;
  @HiveField(12)
  bool? firstInvoice;
  @HiveField(13)
  bool? firstDebt;
  @HiveField(14)
  bool? firstCreadit;
  @HiveField(15)
  bool? firstInvest;
  @HiveField(16)
  String? homeChartType;
  @HiveField(17)
  int? fastReportDayRang;

  LocalSetting({
    this.isLock,
    this.password,
    this.active,
    this.init,
    this.ipgStatus,
    this.timeLeft,
    this.dateupdate,
    this.smartLink,
    this.pageIntro,
    this.smartConnect,
    this.smartView,
    this.backup,
    required this.firstInvoice,
    required this.firstDebt,
    required this.firstCreadit,
    required this.firstInvest,
    required this.homeChartType,
    required this.fastReportDayRang,
  });

  Map toJson() => {
    'isLock': isLock,
    'password': password,
    'active': active,
    'init': init,
    'ipgStatus': ipgStatus,
    'timeLeft': timeLeft,
    'dateupdate': dateupdate,
    'smartLink': smartLink,
    'pageIntro': pageIntro,
    'smartConnect': smartConnect,
    'smartView': smartView,
    'backup': backup,
    'firstInvoice': firstInvoice,
    'firstDebt': firstDebt,
    'firstCreadit': firstCreadit,
    'firstInvest': firstInvest,
    'homeChartType': homeChartType,
    'fastReportDayRang': fastReportDayRang,
  };
}

@HiveType(typeId: 16)
class LoginData {
  @HiveField(0)
  String? mobile;
  @HiveField(1)
  String? code;
  @HiveField(2)
  String? id;
  @HiveField(3)
  String? brand;
  @HiveField(4)
  String? model;
  @HiveField(5)
  String? os;
  @HiveField(6)
  String? osVersion;
  @HiveField(7, defaultValue: 0)
  int? inserter;

  LoginData({this.mobile, this.code, this.id, this.brand, this.model, this.os, this.osVersion, required this.inserter});
  Map toJson() => {'mobile': mobile, 'code': code, 'id': id, 'brand': brand, 'model': model, 'os': os, 'osVersion': osVersion, 'inserter': inserter};
}

@HiveType(typeId: 17)
class FCM {
  @HiveField(0)
  String? token;
  @HiveField(1)
  String? device;

  FCM({this.token, this.device});
  Map toJson() => {'token': token, 'device': device};
}

@HiveType(typeId: 18)
class MSG {
  @HiveField(0)
  String? title;
  @HiveField(1)
  String? msg;
  @HiveField(2)
  String? fileName;
  @HiveField(3)
  String? fileType;
  @HiveField(4)
  String? link;
  @HiveField(5)
  bool? read;
  @HiveField(6)
  String? date;
  @HiveField(7)
  String? type; //all-user-location //pay //remember
  @HiveField(8)
  String? id;
  @HiveField(9)
  bool? isPoll;
  @HiveField(10)
  PollType? pollType;
  @HiveField(11)
  String? poll;

  MSG({this.title, this.msg, this.fileName, this.fileType, this.link, this.read, this.date, this.type, this.id, this.isPoll, this.pollType, this.poll});

  Map toJson() => {
    'title': title,
    'msg': msg,
    'fileName': fileName,
    'fileType': fileType,
    'link': link,
    'read': read,
    'date': date,
    'type': type,
    'id': id,
    'isPoll': isPoll,
    'pollType': pollType,
    'poll': poll,
  };
}

@HiveType(typeId: 190)
class PollType {
  @HiveField(0)
  String? type;
  @HiveField(1)
  List? options;
  PollType({this.type, this.options});
  Map toJson() => {'type': type, 'options': options};
}

@HiveType(typeId: 19)
class PatternDB {
  @HiveField(0)
  String? code;
  @HiveField(1)
  int? orderType;
  @HiveField(2)
  String? text;
  @HiveField(3)
  List? pattern;
  @HiveField(4)
  String? status;
  @HiveField(5)
  bool? active;
  @HiveField(6, defaultValue: 'new')
  String? backup;
  @HiveField(7, defaultValue: 0)
  int? inserter;

  PatternDB({this.code, this.orderType, this.text, this.pattern, this.status, this.active, this.backup, required this.inserter});

  Map toJson() => {'code': code, 'orderType': orderType, 'text': text, 'pattern': pattern, 'status': status, 'active': active, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 20)
class SMS {
  @HiveField(0)
  int? personID;
  @HiveField(1)
  SmsPatternValue? smsPatternValue;
  @HiveField(2)
  String? status;
  @HiveField(3)
  String? bulk;
  @HiveField(4)
  String? date;
  @HiveField(5)
  String? patternCode;
  @HiveField(6)
  String? mobile;
  @HiveField(7, defaultValue: 0)
  int? inserter;

  SMS({this.personID, this.patternCode, this.smsPatternValue, this.mobile, this.status, this.bulk, this.date, required this.inserter});

  Map toJson() => {'personID': personID, 'smsPatternValue': smsPatternValue, 'mobile': mobile, 'patternCode': patternCode, 'status': status, 'bulk': bulk, 'date': date, 'inserter': inserter};
}

@HiveType(typeId: 91)
class SmsPatternValue {
  String? name;
  String? price;
  String? factorID;
  String? date;
  String? link;
  SmsPatternValue({this.date, this.factorID, this.link, this.name, this.price});
  Map toJson() => {'name': name, 'price': price, 'factorID': factorID, 'date': date, 'link': link};
}

class ProductPropertyValue {
  String name;
  String code;
  int id;
  ProductPropertyValue({required this.name, this.code = '', required this.id});
  Map toJson() => {'name': name, 'code': code, 'id': id};
}

enum ProductPropertyType { other, color, size, part }

@HiveType(typeId: 21)
class ProductPropertyDB {
  //تعریف ویژگی ها
  @HiveField(0)
  String uid;
  @HiveField(1)
  String name;
  @HiveField(2)
  List value;
  @HiveField(3, defaultValue: 'other')
  String? type;
  @HiveField(4, defaultValue: 'new')
  String? backup;
  @HiveField(5, defaultValue: 0)
  int? inserter;

  ProductPropertyDB({required this.uid, required this.name, required this.value, this.type, this.backup, required this.inserter});

  Map toJson() => {'uid': uid, 'name': name, 'value': value, 'type': type, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 22)
class ProductProDB {
  @HiveField(0)
  String? uid;
  @HiveField(1)
  String? productUID;
  @HiveField(2)
  List? property; //[{uid: propertyUID,vid: peroperty value id},{...}]
  @HiveField(3)
  String? desc;
  @HiveField(4, defaultValue: 'new')
  String? backup;
  @HiveField(5, defaultValue: 0)
  int? inserter;

  ProductProDB({required this.uid, required this.productUID, required this.property, this.desc, this.backup, required this.inserter});
  Map toJson() => {'uid': uid, 'productUID': productUID, 'property': property, 'desc': desc, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 23)
class TemporaryProduct {
  @HiveField(0)
  String? name;
  @HiveField(1)
  List<String>? catIDList;
  @HiveField(2)
  List<int>? sellPrice;
  @HiveField(3)
  int? buyPrice;
  @HiveField(4)
  double? commission;
  @HiveField(5)
  List? img;
  @HiveField(6)
  int? stock;
  @HiveField(7)
  bool? isCommissionFixed;
  @HiveField(8)
  String? catName;
  @HiveField(9)
  String? barcode;
  @HiveField(10)
  int? id;
  @HiveField(11, defaultValue: 0.0)
  double? vat;
  @HiveField(12)
  int? unitCode;
  TemporaryProduct({
    this.name,
    this.catIDList,
    this.catName,
    this.sellPrice,
    this.buyPrice,
    this.commission,
    this.isCommissionFixed,
    this.stock,
    this.barcode,
    this.img,
    this.id,
    required this.unitCode,
    required this.vat,
  });
  Map toJson() => {
    'name': name,
    'catIDList': catIDList,
    'catName': catName,
    'sellPrice': sellPrice,
    'buyPrice': buyPrice,
    'commission': commission,
    'isCommissionFixed': isCommissionFixed,
    'stock': stock,
    'barcode': barcode,
    'img': img,
    'id': id,
    'unitCode': unitCode,
    'vat': vat,
  };
}

@HiveType(typeId: 24)
class ChequeDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  int? bankID;
  @HiveField(2)
  String? branch;
  @HiveField(3)
  int? branchNo;
  @HiveField(4)
  String? accNo;
  @HiveField(5)
  String? chequeNo;
  @HiveField(6)
  int? price;
  @HiveField(7)
  int? holder; //darandeh cheque
  @HiveField(8)
  int? payee; //girande cheque
  @HiveField(9)
  int? status; //0: سررسید نشده 1:پاس شده 2: پاس نشده
  @HiveField(10)
  String? desc;
  @HiveField(11)
  String? date;
  @HiveField(12)
  String? dueDate;
  @HiveField(13)
  String? to;
  @HiveField(14)
  int? billID;
  @HiveField(15, defaultValue: 'new')
  String? backup;
  @HiveField(16, defaultValue: 0)
  int? inserter;
  @HiveField(17, defaultValue: '')
  String? uid;
  @HiveField(18, defaultValue: '')
  String? toUID;
  @HiveField(19)
  String? billUID;
  @HiveField(20)
  String? holderUID; //darandeh cheque
  @HiveField(21)
  String? payeeUID; //girande cheque
  ChequeDB({
    this.id,
    required this.uid,
    this.billID,
    required this.billUID,
    this.accNo,
    this.bankID,
    this.branch,
    this.branchNo,
    this.chequeNo,
    this.date,
    this.desc,
    this.dueDate,
    this.holder,
    this.payee,
    this.price,
    this.status,
    this.to,
    required this.toUID,
    this.backup,
    required this.inserter,
    required this.holderUID,
    required this.payeeUID,
  });
  Map toJson() => {
    'id': id,
    'uid': uid,
    'billID': billID,
    'billUID': billUID,
    'accNo': accNo,
    'bankID': bankID,
    'branch': branch,
    'branchNo': branchNo,
    'chequeNo': chequeNo,
    'date': date,
    'desc': desc,
    'dueDate': dueDate,
    'holder': holder,
    'payee': payee,
    'price': price,
    'status': status,
    'to': to,
    'toUID': toUID,
    'backup': backup,
    'inserter': inserter,
    'holderUID': holderUID,
    'payeeUID': payeeUID,
  };
}

@HiveType(typeId: 25)
class WarehouseNameDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String name;
  @HiveField(2)
  bool active;
  @HiveField(3, defaultValue: 'new')
  String? backup;
  @HiveField(4, defaultValue: 0)
  int? inserter;
  @HiveField(5, defaultValue: '')
  String? uid;

  WarehouseNameDB({required this.id, required this.uid, required this.name, required this.active, this.backup, required this.inserter});
  Map toJson() => {'id': id, 'uid': uid, 'name': name, 'active': active, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 26)
class WarehouseDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String wuid;
  @HiveField(2)
  String puid;
  @HiveField(3)
  String prouid;
  @HiveField(4)
  double inventory;
  @HiveField(5, defaultValue: 'new')
  String? backup;
  @HiveField(6, defaultValue: 0)
  int? inserter;
  @HiveField(7)
  String? uid;
  WarehouseDB({required this.id, required this.uid, required this.wuid, required this.puid, required this.prouid, required this.inventory, this.backup, required this.inserter});
  Map toJson() => {'id': id, 'uid': uid, 'wuid': wuid, 'puid': puid, 'inventory': inventory, 'prouid': prouid, 'backup': backup, 'inserter': inserter};
}

@HiveType(typeId: 27)
class WarehouseHistoryDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String parentuid;
  @HiveField(2)
  String from;
  @HiveField(3)
  String to;
  @HiveField(4)
  String date;
  @HiveField(5)
  String by;
  @HiveField(6)
  String type; //W2W - W2I - I2W
  @HiveField(7)
  String puid;
  @HiveField(8)
  String prouid;
  @HiveField(9)
  double amount;
  @HiveField(10, defaultValue: 'new')
  String? backup;
  @HiveField(11, defaultValue: 0)
  int? inserter;
  @HiveField(12, defaultValue: '')
  String? uid;

  WarehouseHistoryDB({
    required this.id,
    required this.uid,
    required this.parentuid,
    required this.from,
    required this.to,
    required this.date,
    required this.by,
    required this.type,
    required this.puid,
    required this.prouid,
    required this.amount,
    this.backup,
    required this.inserter,
  });
  Map toJson() => {
    'id': id,
    'uid': uid,
    'parentuid': parentuid,
    'from': from,
    'to': to,
    'date': date,
    'by': by,
    'type': type,
    'puid': puid,
    'prouid': prouid,
    'amount': amount,
    'backup': backup,
    'inserter': inserter,
  };
}

@HiveType(typeId: 28)
class ConnectionDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String? personUID;
  @HiveField(2)
  String? desc;
  @HiveField(3)
  String? date;
  @HiveField(4, defaultValue: '')
  String? nextDate;
  @HiveField(5)
  int? by;
  @HiveField(6, defaultValue: '')
  String? status;
  @HiveField(7)
  String? parent;
  @HiveField(8)
  bool result;
  @HiveField(9, defaultValue: 'new')
  String? backup;
  @HiveField(10, defaultValue: 0)
  int? inserter;
  @HiveField(11, defaultValue: '')
  String? uid;

  ConnectionDB({
    required this.id,
    required this.uid,
    required this.by,
    required this.date,
    required this.desc,
    required this.parent,
    this.nextDate,
    required this.result,
    required this.personUID,
    required this.status,
    this.backup,
    required this.inserter,
  });
  Map toJson() => {
    'id': id,
    'uid': uid,
    'personUID': personUID,
    'desc': desc,
    'date': date,
    'parent': parent,
    'result': result,
    'nextDate': nextDate,
    'by': by,
    'status': status,
    'backup': backup,
    'inserter': inserter,
  };
}

@HiveType(typeId: 29)
class MiKYarDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String? mobile;
  @HiveField(2)
  String? name;
  @HiveField(3)
  String? post;
  @HiveField(4)
  String? permission;
  @HiveField(5)
  String? permissionUID;
  @HiveField(6, defaultValue: 0)
  int? inserter;
  @HiveField(7, defaultValue: 'new')
  String? backup;
  @HiveField(8, defaultValue: true)
  bool? active;

  MiKYarDB({
    required this.id,
    required this.mobile,
    required this.name,
    required this.post,
    required this.permission,
    required this.permissionUID,
    required this.inserter,
    required this.active,
    this.backup,
  });
  Map toJson() => {'id': id, 'mobile': mobile, 'name': name, 'post': post, 'permission': permission, 'permissionUID': permissionUID, 'inserter': inserter, 'active': active, 'backup': backup};
}

@HiveType(typeId: 30)
class MiKYarPermissionDB {
  List<String> get permissionNames => PermissionCatalog.decode(permission).toList();
  set permissionNames(List<String> names) {
    permission = PermissionCatalog.encodeLegacy(names, original: permission);
  }

  @HiveField(0)
  int id;
  @HiveField(1)
  String? name;
  @HiveField(2)
  String? permission;
  @HiveField(3, defaultValue: 0)
  int? inserter;
  @HiveField(4, defaultValue: 'new')
  String? backup;
  @HiveField(5, defaultValue: '')
  String? uid;

  MiKYarPermissionDB({required this.id, required this.uid, required this.name, required this.permission, required this.inserter, this.backup});
  Map toJson() => {'id': id, 'uid': uid, 'name': name, 'permission': permission, 'inserter': inserter, 'backup': backup};
}

@HiveType(typeId: 31)
class MiKYarPermissionExtDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  int yarID;
  @HiveField(2)
  List<String>? branch;
  @HiveField(3)
  List<String>? warehouse;
  @HiveField(4, defaultValue: 0)
  int? inserter;
  @HiveField(5, defaultValue: 'new')
  String? backup;
  @HiveField(6, defaultValue: '')
  String? uid;

  MiKYarPermissionExtDB({required this.id, required this.uid, required this.yarID, required this.branch, required this.warehouse, required this.inserter, this.backup});

  Map toJson() => {'id': id, 'uid': uid, 'yarID': yarID, 'branch': branch, 'warehouse': warehouse, 'inserter': inserter, 'backup': backup};
}

@HiveType(typeId: 32)
class BranchDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String name;
  @HiveField(2)
  bool? active;
  @HiveField(3)
  String? description;
  @HiveField(4)
  String? address;
  @HiveField(5)
  String? location;
  @HiveField(6, defaultValue: 0)
  int? inserter;
  @HiveField(7, defaultValue: 'new')
  String? backup;
  @HiveField(8, defaultValue: '')
  String? uid;
  @HiveField(9)
  String? defaultWarehouse;

  BranchDB({
    required this.id,
    required this.uid,
    required this.name,
    required this.active,
    required this.defaultWarehouse,
    this.description,
    this.address,
    this.location,
    required this.inserter,
    this.backup,
  });

  Map toJson() => {
    'id': id,
    'uid': uid,
    'name': name,
    'active': active,
    'defaultWarehouse': defaultWarehouse,
    'description': description,
    'address': address,
    'location': location,
    'inserter': inserter,
    'backup': backup,
  };
}

@HiveType(typeId: 33)
class BranchAccessDB {
  @HiveField(0)
  int id;
  @HiveField(1)
  String branchUID;
  @HiveField(2)
  List<String>? warehouseUID;
  @HiveField(3, defaultValue: 0)
  int? inserter;
  @HiveField(4, defaultValue: 'new')
  String? backup;
  @HiveField(5, defaultValue: '')
  String? uid;

  BranchAccessDB({required this.id, required this.uid, required this.branchUID, required this.warehouseUID, required this.inserter, this.backup});

  Map toJson() => {'id': id, 'uid': uid, 'branchUID': branchUID, 'warehouseUID': warehouseUID, 'inserter': inserter, 'backup': backup};
}

@HiveType(typeId: 34)
class ProductPriceDB {
  @HiveField(0)
  String? uid;
  @HiveField(1)
  String? puid;
  @HiveField(2)
  Map? pro; //
  @HiveField(3)
  int? price;
  @HiveField(4)
  String? name;
  @HiveField(5)
  String? dateValid;
  @HiveField(6)
  bool defaultPrice;
  @HiveField(7, defaultValue: 0)
  int? inserter;
  @HiveField(8, defaultValue: 'new')
  String? backup;
  ProductPriceDB({
    required this.uid,
    required this.puid,
    required this.pro, //MAP {proUID:price}
    required this.price,
    required this.name,
    required this.defaultPrice,
    this.dateValid,
    required this.inserter,
    required this.backup,
  });
  Map toJson() => {"uid": uid, "puid": puid, "pro": pro, "price": price, "name": name, "defaultPrice": defaultPrice, "dateValid": dateValid, "inserter": inserter, "backup": backup};
}
// pro:{prouid:1000,}

@HiveType(typeId: 35)
class InvoiceDB {
  @HiveField(0)
  int? id;
  @HiveField(1)
  String? uid;
  @HiveField(2)
  String? personUID;
  @HiveField(3)
  String? branchUID;
  @HiveField(4)
  Map? items;
  //{puid(xx-xxx-xx):[{prouid:xxxx,price:xxx,buyPrice:xxx,amount:xxx,vat:{percent:xx,vatCal:true},parameters:[{name:xxx,amount:xxx,type:fix/persent, mode:add/ded},...],wuid:xxx}],...}
  @HiveField(5)
  List<String>? billUID;
  @HiveField(6)
  String? date;
  @HiveField(7, defaultValue: '')
  String? doc;
  @HiveField(8, defaultValue: [])
  List? parameters;
  //[{name:xxx,amount:xxx,type:fix/persent, mode:add/ded},...] //for extra cost
  @HiveField(9)
  String? type; //sell | buy | pre (pish factor) | converted
  @HiveField(10, defaultValue: {})
  Map? shipping; //{cost:xxx,trakingCode:xxx,company:xxx}
  @HiveField(11, defaultValue: [])
  List? status;
  //[{status:x,date:xxx},...] //status==> 0: submit | 1: Ready to send |‌ 2: Posted | 8: cancel | 9:reject |444:deleted | 900:pf
  @HiveField(12, defaultValue: {})
  Map? commission; //{amount:xxx,status:x,mikyar:xxxxx}
  @HiveField(13)
  String? description;
  @HiveField(14, defaultValue: 0)
  int? inserter; //0: mikapp, mikyarid: mikyar,.....
  @HiveField(15, defaultValue: 'new')
  String? backup;
  InvoiceDB({
    required this.id,
    required this.uid,
    required this.personUID,
    this.branchUID,
    required this.items,
    required this.billUID,
    required this.date,
    this.doc,
    this.parameters,
    required this.type,
    this.shipping,
    required this.status,
    this.commission,
    this.description,
    required this.inserter,
    this.backup,
  });
  Map toJson() => {
    "id": id,
    "uid": uid,
    "personUID": personUID,
    "branchUID": branchUID,
    "items": items,
    "billUID": billUID,
    "date": date,
    "doc": doc,
    "parameters": parameters,
    "type": type,
    "shipping": shipping,
    "status": status,
    "commission": commission,
    "description": description,
    "inserter": inserter,
    "backup": backup,
  };
}

@HiveType(typeId: 36)
class EditInvoiceHistoryDB {
  @HiveField(0)
  String? uid;
  @HiveField(1)
  String? invoiceUID;
  @HiveField(2)
  var oldData;
  @HiveField(3)
  var newData;
  @HiveField(4)
  String? date;
  @HiveField(5, defaultValue: 0)
  int? editor;
  @HiveField(6, defaultValue: 'new')
  String? backup;
  EditInvoiceHistoryDB({required this.uid, required this.invoiceUID, required this.oldData, required this.newData, required this.date, required this.editor, this.backup});
  Map toJson() => {'uid': uid, 'invoiceUID': invoiceUID, 'oldData': oldData, 'newData': newData, 'date': date, 'editor': editor, 'backup': backup};
}

@HiveType(typeId: 37)
class ProductDraftDB {
  @HiveField(0)
  String uid;

  @HiveField(1)
  String name;

  @HiveField(2)
  String createdDate;

  @HiveField(3)
  String? productType; // 'کالا' or 'خدمات'

  // Optional detailed fields
  @HiveField(4)
  List? image;

  @HiveField(5)
  String? sellPrice;

  @HiveField(6)
  String? buyPrice;

  @HiveField(7)
  String? stock;

  @HiveField(8)
  List<String>? categoryUID;

  @HiveField(9)
  int? unitId;

  @HiveField(10)
  String? tax;

  @HiveField(11)
  String? commissionAmount;

  @HiveField(12)
  bool? isCommissionFixed;

  @HiveField(13)
  String? barcode;

  @HiveField(14)
  String? additionalPricesJson; // JSON string for AdditionalPrice list

  @HiveField(15)
  String? propertiesJson; // JSON string for ProductProperty list

  @HiveField(16)
  String? variantsJson; // JSON string for ProductVariant list

  @HiveField(17)
  String? variantPricesJson; // JSON string for variantPrices map

  ProductDraftDB({
    required this.uid,
    required this.name,
    required this.createdDate,
    this.productType,
    this.image,
    this.sellPrice,
    this.buyPrice,
    this.stock,
    this.categoryUID,
    this.unitId,
    this.tax,
    this.commissionAmount,
    this.isCommissionFixed,
    this.barcode,
    this.additionalPricesJson,
    this.propertiesJson,
    this.variantsJson,
    this.variantPricesJson,
  });

  Map toJson() => {
    'uid': uid,
    'name': name,
    'createdDate': createdDate,
    'productType': productType,
    'image': image,
    'sellPrice': sellPrice,
    'buyPrice': buyPrice,
    'stock': stock,
    'categoryUID': categoryUID,
    'unitId': unitId,
    'tax': tax,
    'commissionAmount': commissionAmount,
    'isCommissionFixed': isCommissionFixed,
    'barcode': barcode,
    'additionalPricesJson': additionalPricesJson,
    'propertiesJson': propertiesJson,
    'variantsJson': variantsJson,
    'variantPricesJson': variantPricesJson,
  };
}

@HiveType(typeId: 38)
class OnboardingDraftDB {
  @HiveField(0)
  String uid;

  @HiveField(1)
  String createdDate;

  @HiveField(2)
  String? debtsJson; // JSON string of List<Map<String, String>>

  @HiveField(3)
  String? claimsJson; // JSON string of List<Map<String, String>>

  @HiveField(4)
  String? cashCapitalJson; // JSON string of List<Map<String, String>>

  @HiveField(5)
  String? currentStage; // 'debts', 'claims', 'cashCapital', 'confirmation'

  @HiveField(6)
  String? chatMessagesJson; // JSON string of chat history

  OnboardingDraftDB({required this.uid, required this.createdDate, this.debtsJson, this.claimsJson, this.cashCapitalJson, this.currentStage, this.chatMessagesJson});

  Map toJson() => {
    'uid': uid,
    'createdDate': createdDate,
    'debtsJson': debtsJson,
    'claimsJson': claimsJson,
    'cashCapitalJson': cashCapitalJson,
    'currentStage': currentStage,
    'chatMessagesJson': chatMessagesJson,
  };
}

//TODO: cmd=> flutter pub run build_runner build
