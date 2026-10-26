import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/models/business_summary.dart';

class BusinessSelection extends GetView {
  final List<BusinessSummary> items;
  final String? error;
  final ValueChanged<BusinessSummary> onSelected;
  final Future<void> Function() onLogout;
  const BusinessSelection({
    super.key,
    required this.items,
    this.error,
    required this.onSelected,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'انتخاب کسب‌وکار',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 15),
      if (error != null) Text(error!),
      for (final item in items)
        ListTile(
          title: Text(item.name),
          subtitle: Text('${item.businessId}'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => onSelected(item),
        ),
      BTN(name: 'خروج از حساب', navigate: true, onTap: onLogout),
    ],
  );
}
