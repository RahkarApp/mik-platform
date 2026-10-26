class InvoiceProItemModel {
  String uid;
  double amount;
  int price;
  int buyPrice;
  String warehouseUID;
  List parameters;
  InvoiceProItemModel({
    required this.uid,
    required this.amount,
    required this.price,
    required this.buyPrice,
    required this.warehouseUID,
    required this.parameters,
  });
}

class InvoiceItemModel {
  String name;
  int id;
  String uid;
  List<InvoiceProItemModel> pro;
  String barcode;
  String type;

  InvoiceItemModel({
    required this.id,
    required this.uid,
    required this.pro,
    required this.name,
    required this.barcode,
    required this.type,
  });
  toJson() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'pro': pro
          .map(
            (e) => {
              'uid': e.uid,
              'amount': e.amount,
              'price': e.price,
              'buyPrice': e.buyPrice,
              'warehouseUID': e.warehouseUID,
            },
          )
          .toList(),
      'barcode': barcode,
      'type': type,
    };
  }
}
