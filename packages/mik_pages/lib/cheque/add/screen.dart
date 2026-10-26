import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/header/header.dart';
import 'package:mik_components/base/main/main.dart';

import '../components/form.dart';

class ChequeAddScreen extends GetView {
  const ChequeAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Main(
      initState: () async => {},
      header: Header.page(context, text: 'ثبت چک جدید'),
      child: (d) => ChequeAddForm(),
    );
  }
}
