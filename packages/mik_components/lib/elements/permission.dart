import 'package:flutter/material.dart';
import 'package:mik_consts/colors.dart';

// The original permission chip is shared so both apps keep the same appearance.
class PermissionItem extends StatelessWidget {
  final String name;
  final bool initval, enabled;
  final ValueChanged<bool> callback;
  const PermissionItem({
    required this.name,
    required this.initval,
    required this.callback,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(5),
    child: Semantics(
      button: true,
      selected: initval,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => callback(!initval) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: initval ? AppColors.primary : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: initval ? AppColors.primary : AppColors.grey,
            ),
          ),
          child: Text(
            name,
            style: TextStyle(
              fontSize: 12,
              color: initval ? Colors.white : null,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    ),
  );
}

class PermissionSection extends StatelessWidget {
  final String sectionName;
  final int selectedCount, totalCount;
  final List<Widget> items;
  final bool initiallyExpanded;
  const PermissionSection({
    required this.sectionName,
    required this.selectedCount,
    required this.totalCount,
    required this.items,
    this.initiallyExpanded = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          sectionName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          'تعداد: $selectedCount/$totalCount',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
    children: [Wrap(children: items)],
  );
}
