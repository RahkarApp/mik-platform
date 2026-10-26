import 'package:flutter/material.dart';
import 'package:mik_pages/customers/crm/remote_screen.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});
  @override
  Widget build(BuildContext context) => CustomerCrmScreen(appId: 'mik', showTools: true);
}
