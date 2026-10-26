import 'package:flutter/material.dart';
import 'package:mik_data/models/models.dart';

import 'movements_screen.dart';

class PertnerDetailsScreen extends StatelessWidget {
  final PersonDB item;
  const PertnerDetailsScreen(this.item, {super.key});
  @override
  Widget build(BuildContext context) =>
      PartnerMovementsScreen(appId: 'mik', partnerId: item.uid);
}
