import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/alert.dart';
import 'package:mik_components/base/main/main.dart';
import 'package:mik_components/elements/buttons/button.dart';
import 'package:mik_data/source/remote/models/business_activity.dart';
import 'package:mik_data/source/remote/models/catalog_category.dart';
import 'package:mik_data/utils/fx/business.dart';

import 'activity_option.dart';

class ActivityPicker extends StatefulWidget {
  final BusinessFX business;
  final List<BusinessActivity> selected;
  const ActivityPicker({
    super.key,
    required this.business,
    required this.selected,
  });
  @override
  State<ActivityPicker> createState() => _ActivityPickerState();
}

class _ActivityPickerState extends State<ActivityPicker> {
  final _fields = <String>[].obs, _subs = <String>[].obs;
  final _roots = <CatalogCategory>[], _children = <CatalogCategory>[].obs;
  final _step = 0.obs, _busy = false.obs;
  @override
  void initState() {
    super.initState();
    _fields.addAll(widget.selected.map((e) => e.fieldCode));
    _subs.addAll(widget.selected.expand((e) => e.subfieldCodes));
  }

  Future<Object> _load() async {
    try {
      _roots.clear();
      _roots.addAll(await widget.business.categories());
      if (_roots.isEmpty) {
        throw const FormatException('Empty activity catalog');
      }
      _fields.removeWhere((code) => !_roots.any((item) => item.id == code));
      return _roots;
    } catch (error) {
      throw BusinessFX.message(error);
    }
  }

  Future<void> _next() async {
    if (_busy.value) return;
    if (_fields.isEmpty || _fields.length > 20) {
      Alert.error('بین ۱ تا ۲۰ حوزه انتخاب کنید.');
      return;
    }
    _busy.value = true;
    try {
      final children = <CatalogCategory>[];
      for (final field in _fields) {
        children.addAll(await widget.business.categories(parentCode: field));
      }
      if (!mounted) return;
      _children.assignAll(children);
      _subs.removeWhere((code) => !children.any((e) => e.id == code));
      _step.value = 1;
    } catch (error) {
      if (mounted) Alert.error(BusinessFX.message(error));
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  void _confirm() {
    final result = <BusinessActivity>[];
    for (final field in _fields) {
      final codes = _children
          .where((e) => e.parent == field && _subs.contains(e.id))
          .map((e) => e.id)
          .toList();
      if (codes.isEmpty || codes.length > 30) {
        Alert.error('برای هر حوزه بین ۱ تا ۳۰ زیرحوزه انتخاب کنید.');
        return;
      }
      result.add(BusinessActivity(fieldCode: field, subfieldCodes: codes));
    }
    Get.back(result: result);
  }

  @override
  Widget build(BuildContext context) => Main(
    initState: _load,
    child: (_) => Obx(
      () => Column(
        children: [
          Text(
            _step.value == 0
                ? 'حوزه‌های فعالیت را انتخاب کنید'
                : 'زیرحوزه‌های فعالیت را انتخاب کنید',
          ),
          Expanded(
            child: ListView(
              children: (_step.value == 0 ? _roots : _children).map((item) {
                final choices = _step.value == 0 ? _fields : _subs;
                final parent = _roots
                    .where((e) => e.id == item.parent)
                    .firstOrNull;
                return ActivityOption(
                  name: parent == null
                      ? item.name
                      : '${parent.name} - ${item.name}',
                  selected: choices.contains(item.id),
                  onTap: () {
                    if (_busy.value) return;
                    if (choices.contains(item.id)) {
                      choices.remove(item.id);
                    } else {
                      choices.add(item.id);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          Row(
            children: [
              if (_step.value == 1)
                Expanded(
                  child: BTN(
                    name: 'بازگشت',
                    navigate: true,
                    onTap: () => _step.value = 0,
                  ),
                ),
              Expanded(
                flex: 2,
                child: BTN(
                  name: _step.value == 0 ? 'ادامه' : 'تایید حوزه‌ها',
                  type: BTNType.ok,
                  navigate: true,
                  inLoad: _busy.value,
                  onTap: () async {
                    if (_step.value == 0) {
                      await _next();
                    } else {
                      _confirm();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
