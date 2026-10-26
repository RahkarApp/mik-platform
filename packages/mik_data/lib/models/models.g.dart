// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsDataAdapter extends TypeAdapter<SettingsData> {
  @override
  final int typeId = 0;

  @override
  SettingsData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingsData(
      darkMode: fields[0] as String?,
      dayForCancel: fields[1] as int?,
      animation: fields[2] as bool?,
      factorType: fields[3] as int?,
      factorText: fields[4] as String?,
      factorColor1: fields[5] as String?,
      factorColor2: fields[6] as String?,
      sendSms: fields[7] as SendSmsSetting?,
      skipInit: fields[8] as bool?,
      backup: fields[9] == null ? 'new' : fields[9] as String?,
      dayForPreFactor: fields[10] == null ? 7 : fields[10] as int?,
      usePreFactor: fields[11] == null ? false : fields[11] as bool?,
      factorVat: fields[12] == null ? false : fields[12] as bool?,
      factorLink: fields[13] == null ? false : fields[13] as bool?,
      factorSize: fields[14] == null ? 'a4' : fields[14] as String?,
      factorIsRial: fields[15] == null ? false : fields[15] as bool?,
      connectionStatus: (fields[16] as List?)?.cast<String>(),
      profitInInvoice: fields[17] == null ? 'FIFO' : fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsData obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.darkMode)
      ..writeByte(1)
      ..write(obj.dayForCancel)
      ..writeByte(2)
      ..write(obj.animation)
      ..writeByte(3)
      ..write(obj.factorType)
      ..writeByte(4)
      ..write(obj.factorText)
      ..writeByte(5)
      ..write(obj.factorColor1)
      ..writeByte(6)
      ..write(obj.factorColor2)
      ..writeByte(7)
      ..write(obj.sendSms)
      ..writeByte(8)
      ..write(obj.skipInit)
      ..writeByte(9)
      ..write(obj.backup)
      ..writeByte(10)
      ..write(obj.dayForPreFactor)
      ..writeByte(11)
      ..write(obj.usePreFactor)
      ..writeByte(12)
      ..write(obj.factorVat)
      ..writeByte(13)
      ..write(obj.factorLink)
      ..writeByte(14)
      ..write(obj.factorSize)
      ..writeByte(15)
      ..write(obj.factorIsRial)
      ..writeByte(16)
      ..write(obj.connectionStatus)
      ..writeByte(17)
      ..write(obj.profitInInvoice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SendSmsSettingAdapter extends TypeAdapter<SendSmsSetting> {
  @override
  final int typeId = 90;

  @override
  SendSmsSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SendSmsSetting(
      orderSubmit: fields[0] as bool?,
      orderSended: fields[2] as bool?,
      orderReadySend: fields[1] as bool?,
      orderCancelled: fields[3] as bool?,
      orderDelayTanks: fields[5] as bool?,
      orderReturned: fields[4] as bool?,
      orderOnlinePay: fields[6] as bool?,
      preFactor: fields[7] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, SendSmsSetting obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.orderSubmit)
      ..writeByte(1)
      ..write(obj.orderReadySend)
      ..writeByte(2)
      ..write(obj.orderSended)
      ..writeByte(3)
      ..write(obj.orderCancelled)
      ..writeByte(4)
      ..write(obj.orderReturned)
      ..writeByte(5)
      ..write(obj.orderDelayTanks)
      ..writeByte(6)
      ..write(obj.orderOnlinePay)
      ..writeByte(7)
      ..write(obj.preFactor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SendSmsSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProfileDBAdapter extends TypeAdapter<ProfileDB> {
  @override
  final int typeId = 1;

  @override
  ProfileDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfileDB(
      id: fields[10] as int?,
      name: fields[0] as String?,
      img: fields[1] as String?,
      date: fields[2] as String?,
      cardNumber: (fields[3] as List?)?.cast<dynamic>(),
      shebaNumber: (fields[4] as List?)?.cast<dynamic>(),
      cardNumberName: (fields[5] as List?)?.cast<dynamic>(),
      province: fields[6] as String?,
      city: fields[7] as String?,
      email: fields[8] as String?,
      tel: (fields[9] as List?)?.cast<dynamic>(),
      instagram: fields[11] as String?,
      site: fields[12] as String?,
      slogan: fields[13] as String?,
      referral: fields[14] as String?,
      stateID: fields[15] as int?,
      townID: fields[16] as int?,
      address: fields[17] as String?,
      economicCode: fields[18] as String?,
      mobile: fields[19] as String?,
      type: (fields[20] as List?)?.cast<dynamic>(),
      postalCode: fields[23] == null ? '' : fields[23] as String?,
      backup: fields[21] == null ? 'new' : fields[21] as String?,
      nationalID: fields[22] == null ? '' : fields[22] as String?,
      tspEnabled: fields[24] == null ? false : fields[24] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileDB obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.img)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.cardNumber)
      ..writeByte(4)
      ..write(obj.shebaNumber)
      ..writeByte(5)
      ..write(obj.cardNumberName)
      ..writeByte(6)
      ..write(obj.province)
      ..writeByte(7)
      ..write(obj.city)
      ..writeByte(8)
      ..write(obj.email)
      ..writeByte(9)
      ..write(obj.tel)
      ..writeByte(10)
      ..write(obj.id)
      ..writeByte(11)
      ..write(obj.instagram)
      ..writeByte(12)
      ..write(obj.site)
      ..writeByte(13)
      ..write(obj.slogan)
      ..writeByte(14)
      ..write(obj.referral)
      ..writeByte(15)
      ..write(obj.stateID)
      ..writeByte(16)
      ..write(obj.townID)
      ..writeByte(17)
      ..write(obj.address)
      ..writeByte(18)
      ..write(obj.economicCode)
      ..writeByte(19)
      ..write(obj.mobile)
      ..writeByte(20)
      ..write(obj.type)
      ..writeByte(21)
      ..write(obj.backup)
      ..writeByte(22)
      ..write(obj.nationalID)
      ..writeByte(23)
      ..write(obj.postalCode)
      ..writeByte(24)
      ..write(obj.tspEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PersonDBAdapter extends TypeAdapter<PersonDB> {
  @override
  final int typeId = 2;

  @override
  PersonDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersonDB(
      id: fields[0] as int?,
      uid: fields[26] == null ? '' : fields[26] as String?,
      date: fields[1] as String?,
      name: fields[2] as String?,
      nationalID: fields[3] as String?,
      mobile: fields[4] as String?,
      instagram: fields[5] as String?,
      email: fields[6] as String?,
      cardNumber: fields[7] as String?,
      shebaNumber: fields[8] as String?,
      address: fields[9] as String?,
      isAdmin: fields[10] as bool?,
      isSupplier: fields[11] as bool?,
      isPartner: fields[12] as bool?,
      isCustomer: fields[13] as bool?,
      isMarketer: fields[14] as bool?,
      isService: fields[15] as bool?,
      description: fields[16] as String?,
      stateID: fields[17] as int?,
      townID: fields[18] as int?,
      backup: fields[19] == null ? 'new' : fields[19] as String?,
      orgName: fields[20] as String?,
      org: fields[21] == null ? false : fields[21] as bool?,
      tel: fields[22] as String?,
      economicID: fields[23] as String?,
      postalCode: fields[24] as String?,
      inserter: fields[25] == null ? 0 : fields[25] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PersonDB obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.nationalID)
      ..writeByte(4)
      ..write(obj.mobile)
      ..writeByte(5)
      ..write(obj.instagram)
      ..writeByte(6)
      ..write(obj.email)
      ..writeByte(7)
      ..write(obj.cardNumber)
      ..writeByte(8)
      ..write(obj.shebaNumber)
      ..writeByte(9)
      ..write(obj.address)
      ..writeByte(10)
      ..write(obj.isAdmin)
      ..writeByte(11)
      ..write(obj.isSupplier)
      ..writeByte(12)
      ..write(obj.isPartner)
      ..writeByte(13)
      ..write(obj.isCustomer)
      ..writeByte(14)
      ..write(obj.isMarketer)
      ..writeByte(15)
      ..write(obj.isService)
      ..writeByte(16)
      ..write(obj.description)
      ..writeByte(17)
      ..write(obj.stateID)
      ..writeByte(18)
      ..write(obj.townID)
      ..writeByte(19)
      ..write(obj.backup)
      ..writeByte(20)
      ..write(obj.orgName)
      ..writeByte(21)
      ..write(obj.org)
      ..writeByte(22)
      ..write(obj.tel)
      ..writeByte(23)
      ..write(obj.economicID)
      ..writeByte(24)
      ..write(obj.postalCode)
      ..writeByte(25)
      ..write(obj.inserter)
      ..writeByte(26)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PartnerTransactionDBAdapter extends TypeAdapter<PartnerTransactionDB> {
  @override
  final int typeId = 3;

  @override
  PartnerTransactionDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PartnerTransactionDB(
      id: fields[0] as int?,
      uid: fields[8] == null ? '' : fields[8] as String?,
      partnerID: fields[1] as int?,
      amount: fields[2] as int?,
      status: fields[3] as String?,
      date: fields[4] as String?,
      description: fields[5] as String?,
      backup: fields[6] == null ? 'new' : fields[6] as String?,
      inserter: fields[7] == null ? 0 : fields[7] as int?,
      partnerUID: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PartnerTransactionDB obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.partnerID)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.backup)
      ..writeByte(7)
      ..write(obj.inserter)
      ..writeByte(8)
      ..write(obj.uid)
      ..writeByte(9)
      ..write(obj.partnerUID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerTransactionDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductDBAdapter extends TypeAdapter<ProductDB> {
  @override
  final int typeId = 4;

  @override
  ProductDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductDB(
      id: fields[0] as int?,
      uid: fields[22] == null ? '' : fields[22] as String?,
      taxID: fields[23] == null ? '' : fields[23] as String?,
      name: fields[1] as String?,
      img: (fields[2] as List?)?.cast<dynamic>(),
      categoryID: fields[3] as int?,
      barcode: fields[4] as String?,
      description: fields[5] as String?,
      sellPrice: fields[6] as int?,
      commission: fields[7] as num?,
      isCommissionFixed: fields[8] as bool?,
      date: fields[9] as String?,
      archive: fields[10] as bool?,
      inventory: fields[12] as double?,
      inventoryControl: fields[13] as String?,
      type: fields[14] as String?,
      peropertyID: (fields[15] as List?)?.cast<dynamic>(),
      backup: fields[16] == null ? 'new' : fields[16] as String?,
      vat: fields[17] == null ? 0.0 : fields[17] as double?,
      sellPriceList:
          fields[18] == null ? [] : (fields[18] as List?)?.cast<int>(),
      unitCode: fields[19] == null ? 0 : fields[19] as int?,
      catIDList: (fields[20] as List?)?.cast<String>(),
      inserter: fields[21] == null ? 0 : fields[21] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductDB obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.img)
      ..writeByte(3)
      ..write(obj.categoryID)
      ..writeByte(4)
      ..write(obj.barcode)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.sellPrice)
      ..writeByte(7)
      ..write(obj.commission)
      ..writeByte(8)
      ..write(obj.isCommissionFixed)
      ..writeByte(9)
      ..write(obj.date)
      ..writeByte(10)
      ..write(obj.archive)
      ..writeByte(12)
      ..write(obj.inventory)
      ..writeByte(13)
      ..write(obj.inventoryControl)
      ..writeByte(14)
      ..write(obj.type)
      ..writeByte(15)
      ..write(obj.peropertyID)
      ..writeByte(16)
      ..write(obj.backup)
      ..writeByte(17)
      ..write(obj.vat)
      ..writeByte(18)
      ..write(obj.sellPriceList)
      ..writeByte(19)
      ..write(obj.unitCode)
      ..writeByte(20)
      ..write(obj.catIDList)
      ..writeByte(21)
      ..write(obj.inserter)
      ..writeByte(22)
      ..write(obj.uid)
      ..writeByte(23)
      ..write(obj.taxID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryDBAdapter extends TypeAdapter<CategoryDB> {
  @override
  final int typeId = 5;

  @override
  CategoryDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryDB(
      id: fields[0] as int?,
      uid: fields[6] == null ? '' : fields[6] as String?,
      name: fields[1] as String?,
      parent: fields[7] == null ? '' : fields[7] as String?,
      description: fields[2] as String?,
      type: fields[3] as String?,
      backup: fields[4] == null ? 'new' : fields[4] as String?,
      inserter: fields[5] == null ? 0 : fields[5] as int?,
      isActive: fields[8] == null ? true : fields[8] as bool,
      isCustom: fields[9] == null ? false : fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryDB obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.backup)
      ..writeByte(5)
      ..write(obj.inserter)
      ..writeByte(6)
      ..write(obj.uid)
      ..writeByte(7)
      ..write(obj.parent)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FactorDBAdapter extends TypeAdapter<FactorDB> {
  @override
  final int typeId = 6;

  @override
  FactorDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FactorDB(
      id: fields[0] as int?,
      productID: (fields[1] as List?)?.cast<dynamic>(),
      amount: (fields[2] as List?)?.cast<dynamic>(),
      buyPrice: (fields[3] as List?)?.cast<dynamic>(),
      sellPrice: (fields[4] as List?)?.cast<dynamic>(),
      date: fields[5] as String?,
      personID: fields[6] as int?,
      doc: fields[7] as String?,
      isBuy: fields[8] as bool?,
      shippingCost: fields[10] as int?,
      status: fields[11] as int?,
      statusDate: fields[12] as String?,
      commission: fields[13] as int?,
      cRecipient: fields[14] as int?,
      cStatus: fields[15] as int?,
      discount: fields[16] as num?,
      isDiscountFixed: fields[17] as bool?,
      description: fields[18] as String?,
      excess: fields[9] as int?,
      editDate: fields[19] as String?,
      billID: (fields[20] as List?)?.cast<dynamic>(),
      billUID: (fields[29] as List?)?.cast<String>(),
      uuid: fields[21] as String?,
      trakingCode: fields[22] as String?,
      shippingCompany: fields[23] as String?,
      type: fields[24] as String?,
      backup: fields[25] == null ? 'new' : fields[25] as String?,
      vatCalculated: fields[26] == null ? true : fields[26] as bool?,
      vat: (fields[27] as List?)?.cast<dynamic>(),
      inserter: fields[28] == null ? 0 : fields[28] as int?,
      cRecipientUID: fields[31] as String?,
      productUID: (fields[30] as List?)?.cast<dynamic>(),
      personUID: fields[32] as String?,
    )..items = fields[33] as Object?;
  }

  @override
  void write(BinaryWriter writer, FactorDB obj) {
    writer
      ..writeByte(34)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productID)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.buyPrice)
      ..writeByte(4)
      ..write(obj.sellPrice)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.personID)
      ..writeByte(7)
      ..write(obj.doc)
      ..writeByte(8)
      ..write(obj.isBuy)
      ..writeByte(9)
      ..write(obj.excess)
      ..writeByte(10)
      ..write(obj.shippingCost)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.statusDate)
      ..writeByte(13)
      ..write(obj.commission)
      ..writeByte(14)
      ..write(obj.cRecipient)
      ..writeByte(15)
      ..write(obj.cStatus)
      ..writeByte(16)
      ..write(obj.discount)
      ..writeByte(17)
      ..write(obj.isDiscountFixed)
      ..writeByte(18)
      ..write(obj.description)
      ..writeByte(19)
      ..write(obj.editDate)
      ..writeByte(20)
      ..write(obj.billID)
      ..writeByte(21)
      ..write(obj.uuid)
      ..writeByte(22)
      ..write(obj.trakingCode)
      ..writeByte(23)
      ..write(obj.shippingCompany)
      ..writeByte(24)
      ..write(obj.type)
      ..writeByte(25)
      ..write(obj.backup)
      ..writeByte(26)
      ..write(obj.vatCalculated)
      ..writeByte(27)
      ..write(obj.vat)
      ..writeByte(28)
      ..write(obj.inserter)
      ..writeByte(29)
      ..write(obj.billUID)
      ..writeByte(30)
      ..write(obj.productUID)
      ..writeByte(31)
      ..write(obj.cRecipientUID)
      ..writeByte(32)
      ..write(obj.personUID)
      ..writeByte(33)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FactorDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CostCategoryDBAdapter extends TypeAdapter<CostCategoryDB> {
  @override
  final int typeId = 7;

  @override
  CostCategoryDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CostCategoryDB(
      id: fields[0] as int?,
      uid: fields[5] == null ? '' : fields[5] as String?,
      name: fields[1] as String?,
      description: fields[2] as String?,
      backup: fields[3] == null ? 'new' : fields[3] as String?,
      inserter: fields[4] == null ? 0 : fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CostCategoryDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.backup)
      ..writeByte(4)
      ..write(obj.inserter)
      ..writeByte(5)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostCategoryDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CostDBAdapter extends TypeAdapter<CostDB> {
  @override
  final int typeId = 8;

  @override
  CostDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CostDB(
      id: fields[0] as int?,
      uid: fields[11] == null ? '' : fields[11] as String?,
      categoryID: fields[1] as int?,
      categoryUID: fields[13] as String?,
      name: fields[2] as String?,
      description: fields[3] as String?,
      price: fields[4] as int?,
      factorID: fields[5] as int?,
      personID: fields[6] as int?,
      factorUID: fields[14] as String?,
      personUID: fields[15] as String?,
      date: fields[7] as String?,
      billID: (fields[8] as List?)?.cast<dynamic>(),
      billUID: (fields[12] as List?)?.cast<dynamic>(),
      backup: fields[9] == null ? 'new' : fields[9] as String?,
      inserter: fields[10] == null ? 0 : fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CostDB obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryID)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.factorID)
      ..writeByte(6)
      ..write(obj.personID)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.billID)
      ..writeByte(9)
      ..write(obj.backup)
      ..writeByte(10)
      ..write(obj.inserter)
      ..writeByte(11)
      ..write(obj.uid)
      ..writeByte(12)
      ..write(obj.billUID)
      ..writeByte(13)
      ..write(obj.categoryUID)
      ..writeByte(14)
      ..write(obj.factorUID)
      ..writeByte(15)
      ..write(obj.personUID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JWTAdapter extends TypeAdapter<JWT> {
  @override
  final int typeId = 9;

  @override
  JWT read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JWT(
      token: fields[0] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JWT obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.token);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JWTAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DataQueueAdapter extends TypeAdapter<DataQueue> {
  @override
  final int typeId = 10;

  @override
  DataQueue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataQueue(
      data: fields[0] as dynamic,
      url: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DataQueue obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.data)
      ..writeByte(1)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataQueueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DataToServerAdapter extends TypeAdapter<DataToServer> {
  @override
  final int typeId = 100;

  @override
  DataToServer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataToServer(
      data: fields[0] as dynamic,
      type: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DataToServer obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.data)
      ..writeByte(1)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataToServerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CommissionDBAdapter extends TypeAdapter<CommissionDB> {
  @override
  final int typeId = 11;

  @override
  CommissionDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommissionDB(
      id: fields[0] as int?,
      uid: fields[9] == null ? '' : fields[9] as String?,
      personID: fields[1] as int?,
      factorID: fields[2] as int?,
      factorUID: fields[10] as String?,
      amount: fields[3] as int?,
      type: fields[4] as String?,
      date: fields[5] as String?,
      description: fields[6] as String?,
      backup: fields[7] == null ? 'new' : fields[7] as String?,
      inserter: fields[8] == null ? 0 : fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CommissionDB obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personID)
      ..writeByte(2)
      ..write(obj.factorID)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.backup)
      ..writeByte(8)
      ..write(obj.inserter)
      ..writeByte(9)
      ..write(obj.uid)
      ..writeByte(10)
      ..write(obj.factorUID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommissionDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillDBAdapter extends TypeAdapter<BillDB> {
  @override
  final int typeId = 12;

  @override
  BillDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillDB(
      id: fields[0] as int?,
      uid: fields[12] == null ? '' : fields[12] as String?,
      debtor: fields[1] as int?,
      creditor: fields[2] as int?,
      total: fields[3] as num?,
      paid: fields[4] as num?,
      unPaid: fields[5] as num?,
      to: fields[6] as String?,
      toUID: fields[13] == null ? '' : fields[13] as String?,
      date: fields[7] as String?,
      deadLine: fields[8] as String?,
      type: fields[9] as String?,
      backup: fields[10] == null ? 'new' : fields[10] as String?,
      inserter: fields[11] == null ? 0 : fields[11] as int?,
      debtorUID: fields[14] as String?,
      creditorUID: fields[15] as String?,
      meta: fields[16] == null
          ? {}
          : (fields[16] as Map?)?.cast<dynamic, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, BillDB obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.debtor)
      ..writeByte(2)
      ..write(obj.creditor)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.paid)
      ..writeByte(5)
      ..write(obj.unPaid)
      ..writeByte(6)
      ..write(obj.to)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.deadLine)
      ..writeByte(9)
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.backup)
      ..writeByte(11)
      ..write(obj.inserter)
      ..writeByte(12)
      ..write(obj.uid)
      ..writeByte(13)
      ..write(obj.toUID)
      ..writeByte(14)
      ..write(obj.debtorUID)
      ..writeByte(15)
      ..write(obj.creditorUID)
      ..writeByte(16)
      ..write(obj.meta);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FinancialPeriodAdapter extends TypeAdapter<FinancialPeriod> {
  @override
  final int typeId = 13;

  @override
  FinancialPeriod read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinancialPeriod(
      id: fields[0] as int?,
      uid: fields[9] == null ? '' : fields[9] as String?,
      startDate: fields[1] as String?,
      endDate: fields[2] as String?,
      partnerID: (fields[3] as List?)?.cast<dynamic>(),
      percentage: (fields[4] as List?)?.cast<dynamic>(),
      profit: fields[5] as num?,
      date: fields[6] as String?,
      backup: fields[7] == null ? 'new' : fields[7] as String?,
      inserter: fields[8] == null ? 0 : fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialPeriod obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.partnerID)
      ..writeByte(4)
      ..write(obj.percentage)
      ..writeByte(5)
      ..write(obj.profit)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.backup)
      ..writeByte(8)
      ..write(obj.inserter)
      ..writeByte(9)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinancialPeriodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LocalSettingAdapter extends TypeAdapter<LocalSetting> {
  @override
  final int typeId = 14;

  @override
  LocalSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalSetting(
      isLock: fields[0] as bool?,
      password: fields[1] as String?,
      active: fields[2] as bool?,
      init: fields[3] as bool?,
      ipgStatus: fields[4] as bool?,
      timeLeft: fields[5] as int?,
      dateupdate: fields[6] as String?,
      smartLink: fields[7] as bool?,
      pageIntro: (fields[8] as List?)?.cast<dynamic>(),
      smartConnect: fields[9] as bool?,
      smartView: fields[10] as bool?,
      backup: fields[11] == null ? 'new' : fields[11] as String?,
      firstInvoice: fields[12] as bool?,
      firstDebt: fields[13] as bool?,
      firstCreadit: fields[14] as bool?,
      firstInvest: fields[15] as bool?,
      homeChartType: fields[16] as String?,
      fastReportDayRang: fields[17] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalSetting obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.isLock)
      ..writeByte(1)
      ..write(obj.password)
      ..writeByte(2)
      ..write(obj.active)
      ..writeByte(3)
      ..write(obj.init)
      ..writeByte(4)
      ..write(obj.ipgStatus)
      ..writeByte(5)
      ..write(obj.timeLeft)
      ..writeByte(6)
      ..write(obj.dateupdate)
      ..writeByte(7)
      ..write(obj.smartLink)
      ..writeByte(8)
      ..write(obj.pageIntro)
      ..writeByte(9)
      ..write(obj.smartConnect)
      ..writeByte(10)
      ..write(obj.smartView)
      ..writeByte(11)
      ..write(obj.backup)
      ..writeByte(12)
      ..write(obj.firstInvoice)
      ..writeByte(13)
      ..write(obj.firstDebt)
      ..writeByte(14)
      ..write(obj.firstCreadit)
      ..writeByte(15)
      ..write(obj.firstInvest)
      ..writeByte(16)
      ..write(obj.homeChartType)
      ..writeByte(17)
      ..write(obj.fastReportDayRang);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoginDataAdapter extends TypeAdapter<LoginData> {
  @override
  final int typeId = 16;

  @override
  LoginData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoginData(
      mobile: fields[0] as String?,
      code: fields[1] as String?,
      id: fields[2] as String?,
      brand: fields[3] as String?,
      model: fields[4] as String?,
      os: fields[5] as String?,
      osVersion: fields[6] as String?,
      inserter: fields[7] == null ? 0 : fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, LoginData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.mobile)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.brand)
      ..writeByte(4)
      ..write(obj.model)
      ..writeByte(5)
      ..write(obj.os)
      ..writeByte(6)
      ..write(obj.osVersion)
      ..writeByte(7)
      ..write(obj.inserter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FCMAdapter extends TypeAdapter<FCM> {
  @override
  final int typeId = 17;

  @override
  FCM read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FCM(
      token: fields[0] as String?,
      device: fields[1] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FCM obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.token)
      ..writeByte(1)
      ..write(obj.device);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FCMAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MSGAdapter extends TypeAdapter<MSG> {
  @override
  final int typeId = 18;

  @override
  MSG read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MSG(
      title: fields[0] as String?,
      msg: fields[1] as String?,
      fileName: fields[2] as String?,
      fileType: fields[3] as String?,
      link: fields[4] as String?,
      read: fields[5] as bool?,
      date: fields[6] as String?,
      type: fields[7] as String?,
      id: fields[8] as String?,
      isPoll: fields[9] as bool?,
      pollType: fields[10] as PollType?,
      poll: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MSG obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.msg)
      ..writeByte(2)
      ..write(obj.fileName)
      ..writeByte(3)
      ..write(obj.fileType)
      ..writeByte(4)
      ..write(obj.link)
      ..writeByte(5)
      ..write(obj.read)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.type)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.isPoll)
      ..writeByte(10)
      ..write(obj.pollType)
      ..writeByte(11)
      ..write(obj.poll);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MSGAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PollTypeAdapter extends TypeAdapter<PollType> {
  @override
  final int typeId = 190;

  @override
  PollType read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PollType(
      type: fields[0] as String?,
      options: (fields[1] as List?)?.cast<dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, PollType obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.options);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PollTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PatternDBAdapter extends TypeAdapter<PatternDB> {
  @override
  final int typeId = 19;

  @override
  PatternDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PatternDB(
      code: fields[0] as String?,
      orderType: fields[1] as int?,
      text: fields[2] as String?,
      pattern: (fields[3] as List?)?.cast<dynamic>(),
      status: fields[4] as String?,
      active: fields[5] as bool?,
      backup: fields[6] == null ? 'new' : fields[6] as String?,
      inserter: fields[7] == null ? 0 : fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PatternDB obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.orderType)
      ..writeByte(2)
      ..write(obj.text)
      ..writeByte(3)
      ..write(obj.pattern)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.active)
      ..writeByte(6)
      ..write(obj.backup)
      ..writeByte(7)
      ..write(obj.inserter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatternDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SMSAdapter extends TypeAdapter<SMS> {
  @override
  final int typeId = 20;

  @override
  SMS read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SMS(
      personID: fields[0] as int?,
      patternCode: fields[5] as String?,
      smsPatternValue: fields[1] as SmsPatternValue?,
      mobile: fields[6] as String?,
      status: fields[2] as String?,
      bulk: fields[3] as String?,
      date: fields[4] as String?,
      inserter: fields[7] == null ? 0 : fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SMS obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.personID)
      ..writeByte(1)
      ..write(obj.smsPatternValue)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.bulk)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.patternCode)
      ..writeByte(6)
      ..write(obj.mobile)
      ..writeByte(7)
      ..write(obj.inserter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SMSAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SmsPatternValueAdapter extends TypeAdapter<SmsPatternValue> {
  @override
  final int typeId = 91;

  @override
  SmsPatternValue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SmsPatternValue();
  }

  @override
  void write(BinaryWriter writer, SmsPatternValue obj) {
    writer.writeByte(0);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsPatternValueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductPropertyDBAdapter extends TypeAdapter<ProductPropertyDB> {
  @override
  final int typeId = 21;

  @override
  ProductPropertyDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductPropertyDB(
      uid: fields[0] as String,
      name: fields[1] as String,
      value: (fields[2] as List).cast<dynamic>(),
      type: fields[3] == null ? 'other' : fields[3] as String?,
      backup: fields[4] == null ? 'new' : fields[4] as String?,
      inserter: fields[5] == null ? 0 : fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductPropertyDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.backup)
      ..writeByte(5)
      ..write(obj.inserter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPropertyDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductProDBAdapter extends TypeAdapter<ProductProDB> {
  @override
  final int typeId = 22;

  @override
  ProductProDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductProDB(
      uid: fields[0] as String?,
      productUID: fields[1] as String?,
      property: (fields[2] as List?)?.cast<dynamic>(),
      desc: fields[3] as String?,
      backup: fields[4] == null ? 'new' : fields[4] as String?,
      inserter: fields[5] == null ? 0 : fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductProDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.productUID)
      ..writeByte(2)
      ..write(obj.property)
      ..writeByte(3)
      ..write(obj.desc)
      ..writeByte(4)
      ..write(obj.backup)
      ..writeByte(5)
      ..write(obj.inserter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductProDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TemporaryProductAdapter extends TypeAdapter<TemporaryProduct> {
  @override
  final int typeId = 23;

  @override
  TemporaryProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TemporaryProduct(
      name: fields[0] as String?,
      catIDList: (fields[1] as List?)?.cast<String>(),
      catName: fields[8] as String?,
      sellPrice: (fields[2] as List?)?.cast<int>(),
      buyPrice: fields[3] as int?,
      commission: fields[4] as double?,
      isCommissionFixed: fields[7] as bool?,
      stock: fields[6] as int?,
      barcode: fields[9] as String?,
      img: (fields[5] as List?)?.cast<dynamic>(),
      id: fields[10] as int?,
      unitCode: fields[12] as int?,
      vat: fields[11] == null ? 0.0 : fields[11] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, TemporaryProduct obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.catIDList)
      ..writeByte(2)
      ..write(obj.sellPrice)
      ..writeByte(3)
      ..write(obj.buyPrice)
      ..writeByte(4)
      ..write(obj.commission)
      ..writeByte(5)
      ..write(obj.img)
      ..writeByte(6)
      ..write(obj.stock)
      ..writeByte(7)
      ..write(obj.isCommissionFixed)
      ..writeByte(8)
      ..write(obj.catName)
      ..writeByte(9)
      ..write(obj.barcode)
      ..writeByte(10)
      ..write(obj.id)
      ..writeByte(11)
      ..write(obj.vat)
      ..writeByte(12)
      ..write(obj.unitCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporaryProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChequeDBAdapter extends TypeAdapter<ChequeDB> {
  @override
  final int typeId = 24;

  @override
  ChequeDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChequeDB(
      id: fields[0] as int?,
      uid: fields[17] == null ? '' : fields[17] as String?,
      billID: fields[14] as int?,
      billUID: fields[19] as String?,
      accNo: fields[4] as String?,
      bankID: fields[1] as int?,
      branch: fields[2] as String?,
      branchNo: fields[3] as int?,
      chequeNo: fields[5] as String?,
      date: fields[11] as String?,
      desc: fields[10] as String?,
      dueDate: fields[12] as String?,
      holder: fields[7] as int?,
      payee: fields[8] as int?,
      price: fields[6] as int?,
      status: fields[9] as int?,
      to: fields[13] as String?,
      toUID: fields[18] == null ? '' : fields[18] as String?,
      backup: fields[15] == null ? 'new' : fields[15] as String?,
      inserter: fields[16] == null ? 0 : fields[16] as int?,
      holderUID: fields[20] as String?,
      payeeUID: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChequeDB obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bankID)
      ..writeByte(2)
      ..write(obj.branch)
      ..writeByte(3)
      ..write(obj.branchNo)
      ..writeByte(4)
      ..write(obj.accNo)
      ..writeByte(5)
      ..write(obj.chequeNo)
      ..writeByte(6)
      ..write(obj.price)
      ..writeByte(7)
      ..write(obj.holder)
      ..writeByte(8)
      ..write(obj.payee)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.desc)
      ..writeByte(11)
      ..write(obj.date)
      ..writeByte(12)
      ..write(obj.dueDate)
      ..writeByte(13)
      ..write(obj.to)
      ..writeByte(14)
      ..write(obj.billID)
      ..writeByte(15)
      ..write(obj.backup)
      ..writeByte(16)
      ..write(obj.inserter)
      ..writeByte(17)
      ..write(obj.uid)
      ..writeByte(18)
      ..write(obj.toUID)
      ..writeByte(19)
      ..write(obj.billUID)
      ..writeByte(20)
      ..write(obj.holderUID)
      ..writeByte(21)
      ..write(obj.payeeUID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChequeDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WarehouseNameDBAdapter extends TypeAdapter<WarehouseNameDB> {
  @override
  final int typeId = 25;

  @override
  WarehouseNameDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WarehouseNameDB(
      id: fields[0] as int,
      uid: fields[5] == null ? '' : fields[5] as String?,
      name: fields[1] as String,
      active: fields[2] as bool,
      backup: fields[3] == null ? 'new' : fields[3] as String?,
      inserter: fields[4] == null ? 0 : fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WarehouseNameDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.active)
      ..writeByte(3)
      ..write(obj.backup)
      ..writeByte(4)
      ..write(obj.inserter)
      ..writeByte(5)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarehouseNameDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WarehouseDBAdapter extends TypeAdapter<WarehouseDB> {
  @override
  final int typeId = 26;

  @override
  WarehouseDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WarehouseDB(
      id: fields[0] as int,
      uid: fields[7] as String?,
      wuid: fields[1] as String,
      puid: fields[2] as String,
      prouid: fields[3] as String,
      inventory: fields[4] as double,
      backup: fields[5] == null ? 'new' : fields[5] as String?,
      inserter: fields[6] == null ? 0 : fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WarehouseDB obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.wuid)
      ..writeByte(2)
      ..write(obj.puid)
      ..writeByte(3)
      ..write(obj.prouid)
      ..writeByte(4)
      ..write(obj.inventory)
      ..writeByte(5)
      ..write(obj.backup)
      ..writeByte(6)
      ..write(obj.inserter)
      ..writeByte(7)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarehouseDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WarehouseHistoryDBAdapter extends TypeAdapter<WarehouseHistoryDB> {
  @override
  final int typeId = 27;

  @override
  WarehouseHistoryDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WarehouseHistoryDB(
      id: fields[0] as int,
      uid: fields[12] == null ? '' : fields[12] as String?,
      parentuid: fields[1] as String,
      from: fields[2] as String,
      to: fields[3] as String,
      date: fields[4] as String,
      by: fields[5] as String,
      type: fields[6] as String,
      puid: fields[7] as String,
      prouid: fields[8] as String,
      amount: fields[9] as double,
      backup: fields[10] == null ? 'new' : fields[10] as String?,
      inserter: fields[11] == null ? 0 : fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WarehouseHistoryDB obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.parentuid)
      ..writeByte(2)
      ..write(obj.from)
      ..writeByte(3)
      ..write(obj.to)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.by)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.puid)
      ..writeByte(8)
      ..write(obj.prouid)
      ..writeByte(9)
      ..write(obj.amount)
      ..writeByte(10)
      ..write(obj.backup)
      ..writeByte(11)
      ..write(obj.inserter)
      ..writeByte(12)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WarehouseHistoryDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ConnectionDBAdapter extends TypeAdapter<ConnectionDB> {
  @override
  final int typeId = 28;

  @override
  ConnectionDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConnectionDB(
      id: fields[0] as int,
      uid: fields[11] == null ? '' : fields[11] as String?,
      by: fields[5] as int?,
      date: fields[3] as String?,
      desc: fields[2] as String?,
      parent: fields[7] as String?,
      nextDate: fields[4] == null ? '' : fields[4] as String?,
      result: fields[8] as bool,
      personUID: fields[1] as String?,
      status: fields[6] == null ? '' : fields[6] as String?,
      backup: fields[9] == null ? 'new' : fields[9] as String?,
      inserter: fields[10] == null ? 0 : fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ConnectionDB obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personUID)
      ..writeByte(2)
      ..write(obj.desc)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.nextDate)
      ..writeByte(5)
      ..write(obj.by)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.parent)
      ..writeByte(8)
      ..write(obj.result)
      ..writeByte(9)
      ..write(obj.backup)
      ..writeByte(10)
      ..write(obj.inserter)
      ..writeByte(11)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MiKYarDBAdapter extends TypeAdapter<MiKYarDB> {
  @override
  final int typeId = 29;

  @override
  MiKYarDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MiKYarDB(
      id: fields[0] as int,
      mobile: fields[1] as String?,
      name: fields[2] as String?,
      post: fields[3] as String?,
      permission: fields[4] as String?,
      permissionUID: fields[5] as String?,
      inserter: fields[6] == null ? 0 : fields[6] as int?,
      active: fields[8] == null ? true : fields[8] as bool?,
      backup: fields[7] == null ? 'new' : fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MiKYarDB obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mobile)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.post)
      ..writeByte(4)
      ..write(obj.permission)
      ..writeByte(5)
      ..write(obj.permissionUID)
      ..writeByte(6)
      ..write(obj.inserter)
      ..writeByte(7)
      ..write(obj.backup)
      ..writeByte(8)
      ..write(obj.active);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiKYarDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MiKYarPermissionDBAdapter extends TypeAdapter<MiKYarPermissionDB> {
  @override
  final int typeId = 30;

  @override
  MiKYarPermissionDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MiKYarPermissionDB(
      id: fields[0] as int,
      uid: fields[5] == null ? '' : fields[5] as String?,
      name: fields[1] as String?,
      permission: fields[2] as String?,
      inserter: fields[3] == null ? 0 : fields[3] as int?,
      backup: fields[4] == null ? 'new' : fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MiKYarPermissionDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.permission)
      ..writeByte(3)
      ..write(obj.inserter)
      ..writeByte(4)
      ..write(obj.backup)
      ..writeByte(5)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiKYarPermissionDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MiKYarPermissionExtDBAdapter extends TypeAdapter<MiKYarPermissionExtDB> {
  @override
  final int typeId = 31;

  @override
  MiKYarPermissionExtDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MiKYarPermissionExtDB(
      id: fields[0] as int,
      uid: fields[6] == null ? '' : fields[6] as String?,
      yarID: fields[1] as int,
      branch: (fields[2] as List?)?.cast<String>(),
      warehouse: (fields[3] as List?)?.cast<String>(),
      inserter: fields[4] == null ? 0 : fields[4] as int?,
      backup: fields[5] == null ? 'new' : fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MiKYarPermissionExtDB obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.yarID)
      ..writeByte(2)
      ..write(obj.branch)
      ..writeByte(3)
      ..write(obj.warehouse)
      ..writeByte(4)
      ..write(obj.inserter)
      ..writeByte(5)
      ..write(obj.backup)
      ..writeByte(6)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiKYarPermissionExtDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BranchDBAdapter extends TypeAdapter<BranchDB> {
  @override
  final int typeId = 32;

  @override
  BranchDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BranchDB(
      id: fields[0] as int,
      uid: fields[8] == null ? '' : fields[8] as String?,
      name: fields[1] as String,
      active: fields[2] as bool?,
      defaultWarehouse: fields[9] as String?,
      description: fields[3] as String?,
      address: fields[4] as String?,
      location: fields[5] as String?,
      inserter: fields[6] == null ? 0 : fields[6] as int?,
      backup: fields[7] == null ? 'new' : fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BranchDB obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.active)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.inserter)
      ..writeByte(7)
      ..write(obj.backup)
      ..writeByte(8)
      ..write(obj.uid)
      ..writeByte(9)
      ..write(obj.defaultWarehouse);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BranchAccessDBAdapter extends TypeAdapter<BranchAccessDB> {
  @override
  final int typeId = 33;

  @override
  BranchAccessDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BranchAccessDB(
      id: fields[0] as int,
      uid: fields[5] == null ? '' : fields[5] as String?,
      branchUID: fields[1] as String,
      warehouseUID: (fields[2] as List?)?.cast<String>(),
      inserter: fields[3] == null ? 0 : fields[3] as int?,
      backup: fields[4] == null ? 'new' : fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BranchAccessDB obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.branchUID)
      ..writeByte(2)
      ..write(obj.warehouseUID)
      ..writeByte(3)
      ..write(obj.inserter)
      ..writeByte(4)
      ..write(obj.backup)
      ..writeByte(5)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchAccessDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductPriceDBAdapter extends TypeAdapter<ProductPriceDB> {
  @override
  final int typeId = 34;

  @override
  ProductPriceDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductPriceDB(
      uid: fields[0] as String?,
      puid: fields[1] as String?,
      pro: (fields[2] as Map?)?.cast<dynamic, dynamic>(),
      price: fields[3] as int?,
      name: fields[4] as String?,
      defaultPrice: fields[6] as bool,
      dateValid: fields[5] as String?,
      inserter: fields[7] == null ? 0 : fields[7] as int?,
      backup: fields[8] == null ? 'new' : fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductPriceDB obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.puid)
      ..writeByte(2)
      ..write(obj.pro)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.dateValid)
      ..writeByte(6)
      ..write(obj.defaultPrice)
      ..writeByte(7)
      ..write(obj.inserter)
      ..writeByte(8)
      ..write(obj.backup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPriceDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InvoiceDBAdapter extends TypeAdapter<InvoiceDB> {
  @override
  final int typeId = 35;

  @override
  InvoiceDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceDB(
      id: fields[0] as int?,
      uid: fields[1] as String?,
      personUID: fields[2] as String?,
      branchUID: fields[3] as String?,
      items: (fields[4] as Map?)?.cast<dynamic, dynamic>(),
      billUID: (fields[5] as List?)?.cast<String>(),
      date: fields[6] as String?,
      doc: fields[7] == null ? '' : fields[7] as String?,
      parameters:
          fields[8] == null ? [] : (fields[8] as List?)?.cast<dynamic>(),
      type: fields[9] as String?,
      shipping: fields[10] == null
          ? {}
          : (fields[10] as Map?)?.cast<dynamic, dynamic>(),
      status: fields[11] == null ? [] : (fields[11] as List?)?.cast<dynamic>(),
      commission: fields[12] == null
          ? {}
          : (fields[12] as Map?)?.cast<dynamic, dynamic>(),
      description: fields[13] as String?,
      inserter: fields[14] == null ? 0 : fields[14] as int?,
      backup: fields[15] == null ? 'new' : fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceDB obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.uid)
      ..writeByte(2)
      ..write(obj.personUID)
      ..writeByte(3)
      ..write(obj.branchUID)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.billUID)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.doc)
      ..writeByte(8)
      ..write(obj.parameters)
      ..writeByte(9)
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.shipping)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.commission)
      ..writeByte(13)
      ..write(obj.description)
      ..writeByte(14)
      ..write(obj.inserter)
      ..writeByte(15)
      ..write(obj.backup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EditInvoiceHistoryDBAdapter extends TypeAdapter<EditInvoiceHistoryDB> {
  @override
  final int typeId = 36;

  @override
  EditInvoiceHistoryDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EditInvoiceHistoryDB(
      uid: fields[0] as String?,
      invoiceUID: fields[1] as String?,
      oldData: fields[2] as dynamic,
      newData: fields[3] as dynamic,
      date: fields[4] as String?,
      editor: fields[5] == null ? 0 : fields[5] as int?,
      backup: fields[6] == null ? 'new' : fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EditInvoiceHistoryDB obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.invoiceUID)
      ..writeByte(2)
      ..write(obj.oldData)
      ..writeByte(3)
      ..write(obj.newData)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.editor)
      ..writeByte(6)
      ..write(obj.backup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditInvoiceHistoryDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ProductDraftDBAdapter extends TypeAdapter<ProductDraftDB> {
  @override
  final int typeId = 37;

  @override
  ProductDraftDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductDraftDB(
      uid: fields[0] as String,
      name: fields[1] as String,
      createdDate: fields[2] as String,
      productType: fields[3] as String?,
      image: (fields[4] as List?)?.cast<dynamic>(),
      sellPrice: fields[5] as String?,
      buyPrice: fields[6] as String?,
      stock: fields[7] as String?,
      categoryUID: (fields[8] as List?)?.cast<String>(),
      unitId: fields[9] as int?,
      tax: fields[10] as String?,
      commissionAmount: fields[11] as String?,
      isCommissionFixed: fields[12] as bool?,
      barcode: fields[13] as String?,
      additionalPricesJson: fields[14] as String?,
      propertiesJson: fields[15] as String?,
      variantsJson: fields[16] as String?,
      variantPricesJson: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductDraftDB obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.createdDate)
      ..writeByte(3)
      ..write(obj.productType)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.sellPrice)
      ..writeByte(6)
      ..write(obj.buyPrice)
      ..writeByte(7)
      ..write(obj.stock)
      ..writeByte(8)
      ..write(obj.categoryUID)
      ..writeByte(9)
      ..write(obj.unitId)
      ..writeByte(10)
      ..write(obj.tax)
      ..writeByte(11)
      ..write(obj.commissionAmount)
      ..writeByte(12)
      ..write(obj.isCommissionFixed)
      ..writeByte(13)
      ..write(obj.barcode)
      ..writeByte(14)
      ..write(obj.additionalPricesJson)
      ..writeByte(15)
      ..write(obj.propertiesJson)
      ..writeByte(16)
      ..write(obj.variantsJson)
      ..writeByte(17)
      ..write(obj.variantPricesJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDraftDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OnboardingDraftDBAdapter extends TypeAdapter<OnboardingDraftDB> {
  @override
  final int typeId = 38;

  @override
  OnboardingDraftDB read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OnboardingDraftDB(
      uid: fields[0] as String,
      createdDate: fields[1] as String,
      debtsJson: fields[2] as String?,
      claimsJson: fields[3] as String?,
      cashCapitalJson: fields[4] as String?,
      currentStage: fields[5] as String?,
      chatMessagesJson: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OnboardingDraftDB obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.createdDate)
      ..writeByte(2)
      ..write(obj.debtsJson)
      ..writeByte(3)
      ..write(obj.claimsJson)
      ..writeByte(4)
      ..write(obj.cashCapitalJson)
      ..writeByte(5)
      ..write(obj.currentStage)
      ..writeByte(6)
      ..write(obj.chatMessagesJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingDraftDBAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
