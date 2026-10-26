import 'package:flutter/material.dart';
import 'package:mik_pages/customers/crm/remote_screen.dart';

class CRMConnectionsAdd extends StatelessWidget {
  final String? puid, pname, parentUID;
  const CRMConnectionsAdd({this.puid, this.pname, this.parentUID, super.key});
  @override
  Widget build(BuildContext context) =>
      CustomerCrmScreen(appId: 'mik', customerId: puid, startAdd: true);
}
