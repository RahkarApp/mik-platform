// ignore_for_file: must_be_immutable, unnecessary_null_comparison, non_constant_identifier_names, avoid_function_literals_in_foreach_calls, prefer_typing_uninitialized_variables, unintended_html_in_doc_comment

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mik_components/base/responsive.dart';
import 'package:mik_variables/variable.dart';

import 'input.dart';

class ItemValue {
  const ItemValue({required this.text, required this.data});

  final String text;
  final data;
}

class Dropdown extends StatefulWidget {
  Color? fillColor;
  String? name;
  bool? require;
  bool disable;
  bool? search;

  ///if itemValue=false or null items List<String> else items =[{'label':val,.....}]
  final List<String>? items_String;
  final List<ItemValue>? items_Value;
  bool itemValue = false;
  bool multiSelect = false;
  ValueSetter onChange;
  var defaultValue;
  bool? hint;
  String? waitText;

  /// items_String OR items_Value is required
  Dropdown({
    super.key,
    this.fillColor,
    this.name,
    this.hint = true,
    this.require,
    this.defaultValue,
    this.waitText,
    this.itemValue = false,
    this.multiSelect = false,
    this.search = true,
    this.disable = false,
    this.items_String,
    this.items_Value,
    required this.onChange,
  });
  // : assert(
  //       (waitText == null &&
  //           (items_String == null) ^ (items_Value == null)),
  //       'items and itemValues are mutually exclusive');
  @override
  State<Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<Dropdown> {
  final _fcs = FocusNode();
  final _ctl = TextEditingController();
  final searchCtl = TextEditingController();
  final change = false.obs;
  List<ItemValue> selectedItems_Value = <ItemValue>[];
  List<String> selectedItems_Value_Text = <String>[];
  List<String> selectedItems_String = <String>[];
  String? get name => widget.name;
  bool? get require => widget.require;
  bool get disable => widget.disable;
  bool? get search => widget.search;
  List<String>? get items_String => widget.items_String;
  List<ItemValue>? get items_Value => widget.items_Value;
  bool get itemValue => widget.itemValue;
  bool get multiSelect => widget.multiSelect;
  ValueSetter get onChange => widget.onChange;
  dynamic get defaultValue => widget.defaultValue;
  bool? get hint => widget.hint;
  String? get waitText => widget.waitText;
  String? selectedValue_String;
  ItemValue? selectedValue_Value;
  @override
  void dispose() {
    _fcs.dispose();
    _ctl.dispose();
    searchCtl.dispose();
    super.dispose();
  }
  // RxString sv = ''.obs;

  @override
  Widget build(BuildContext context) {
    if (itemValue) {
      if (defaultValue is List) {
        final selected = List<ItemValue>.from(defaultValue);
        selectedItems_Value = (items_Value ?? <ItemValue>[])
            .where((item) => selected.any((value) => value.data == item.data))
            .toList();
        _ctl.text = selectedItems_Value.map((item) => item.text).join('، ');
      } else {
        // Defaults may be rebuilt independently of the options. DropdownButton
        // needs the actual menu instance, matched by data rather than identity.
        final value = defaultValue;
        final matches = (items_Value ?? <ItemValue>[])
            .where((item) => value is ItemValue && item.data == value.data)
            .toList();
        selectedValue_Value = matches.length == 1 ? matches.single : null;
        _ctl.text = selectedValue_Value?.text ?? '';
      }
    } else {
      selectedValue_String = defaultValue;
      _ctl.text = defaultValue ?? '';
    }
    return //Stack(children: [
    SizedBox(
      width: double.maxFinite,
      child:
          (itemValue && (items_Value == null || items_Value!.isEmpty)) ||
              (!itemValue && (items_String == null || items_String!.isEmpty))
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              height: 37,
              child: Text(waitText ?? 'گزینه‌های انتخابی ($name) یافت نشد!'),
            )
          : disable
          ? Input(
              controller: _ctl,
              name: name ?? '',
              readOnly: true,
              enabled: false,
            )
          : DropdownButtonHideUnderline(
              child: Obx(
                () => change.isFalse || change.isTrue
                    ? itemValue
                          ? DropdownButton2<ItemValue>(
                              customButton: Input(
                                controller: _ctl,
                                name: name ?? '',
                                readOnly: true,
                                require: require,
                                inDropDown: true,
                                enabled: false,
                                suffixIcon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                ),
                              ),
                              isExpanded: true,
                              focusNode: _fcs,
                              hint: _text(context, (hint ?? true) ? name : ''),
                              enableFeedback: true,

                              items: items_Value!
                                  .map(
                                    (item) => DropdownMenuItem<ItemValue>(
                                      value: item,
                                      enabled: !multiSelect,
                                      child: multiSelect
                                          ? Obx(() {
                                                change.value;
                                                final isSelected =
                                                    selectedItems_Value.any(
                                                      (value) =>
                                                          value.data ==
                                                          item.data,
                                                    );
                                                return InkWell(
                                                  onTap: () {
                                                    isSelected
                                                        ? selectedItems_Value
                                                              .removeWhere(
                                                                (value) =>
                                                                    value
                                                                        .data ==
                                                                    item.data,
                                                              )
                                                        : selectedItems_Value
                                                              .add(item);
                                                    _ctl.text =
                                                        selectedItems_Value
                                                            .map(
                                                              (value) =>
                                                                  value.text,
                                                            )
                                                            .join('، ');
                                                    onChange(
                                                      List<ItemValue>.from(
                                                        selectedItems_Value,
                                                      ),
                                                    );
                                                    change.toggle();
                                                  },
                                                  child: Container(
                                                    height: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16.0,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        if (isSelected)
                                                          const Icon(
                                                            Icons
                                                                .check_box_outlined,
                                                          )
                                                        else
                                                          const Icon(
                                                            Icons
                                                                .check_box_outline_blank,
                                                          ),
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            item.text,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize:
                                                                      15.7,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Text(
                                              item.text,
                                              style: const TextStyle(
                                                fontSize: 15.7,
                                              ),
                                            ),
                                    ),
                                  )
                                  .toList(),
                              value: multiSelect
                                  ? (selectedItems_Value.isEmpty
                                        ? null
                                        : selectedItems_Value.last)
                                  : selectedValue_Value,
                              onChanged: (value) {
                                if (multiSelect) return;
                                _ctl.text = value?.text ?? '';
                                selectedValue_Value = value;
                                onChange(value);
                                change.toggle();
                              },
                              dropdownSearchData: search!
                                  ? DropdownSearchData(
                                      searchInnerWidgetHeight: 60,
                                      searchController: searchCtl,
                                      searchInnerWidget: Input(
                                        name: 'جستجو',
                                        style: 2,
                                        // fillColor: darkMode.isFalse
                                        //     ? Colors.grey.shade300
                                        //     : null,
                                        controller: searchCtl,
                                      ),
                                      searchMatchFn: (item, searchValue) {
                                        return item.value!.text
                                            .toString()
                                            .contains(searchValue);
                                      },
                                    )
                                  : null,
                              selectedItemBuilder: multiSelect
                                  ? (context) {
                                      selectedItems_Value_Text = [];
                                      selectedItems_Value.forEach((element) {
                                        selectedItems_Value_Text.add(
                                          element.text,
                                        );
                                      });
                                      return items_Value!.map((item) {
                                        return Container(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Text(
                                            selectedItems_Value_Text.join(', '),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    }
                                  : null,
                              dropdownStyleData: _dropdownStyleData(context),
                              buttonStyleData: _buttonStyleData(),
                              menuItemStyleData: _menuItemStyleData(),
                            )
                          : DropdownButton2<String>(
                              isExpanded: true,
                              focusNode: _fcs,
                              customButton: Input(
                                controller: _ctl,
                                name: name ?? '',
                                readOnly: true,
                                require: require,
                                inDropDown: true,
                                enabled: false,
                                suffixIcon: const Icon(
                                  Icons.arrow_drop_down,
                                  size: 20,
                                ),
                              ),
                              hint: _text(context, (hint ?? true) ? name : ''),
                              enableFeedback: true,
                              items: items_String!
                                  .map(
                                    (item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              value: multiSelect
                                  ? (selectedItems_String.isEmpty
                                        ? null
                                        : selectedItems_String.last)
                                  : selectedValue_String,
                              onChanged: (value) {
                                _ctl.text = value ?? '';
                                selectedValue_String = value;
                                onChange(value);
                                // change.toggle();
                              },
                              dropdownSearchData: search!
                                  ? DropdownSearchData(
                                      searchInnerWidgetHeight: 60,
                                      searchController: searchCtl,
                                      searchInnerWidget: Input(
                                        name: 'جستجو',
                                        style: 2,
                                        // fillColor: darkMode.isFalse
                                        //     ? Colors.grey.shade300
                                        //     : null,
                                        controller: searchCtl,
                                      ),
                                      searchMatchFn: (item, searchValue) {
                                        return item.value.toString().contains(
                                          searchValue,
                                        );
                                      },
                                    )
                                  : null,
                              selectedItemBuilder: multiSelect
                                  ? (context) {
                                      return selectedItems_String.map((item) {
                                        return Container(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: Text(
                                            selectedItems_String.join(', '),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList();
                                    }
                                  : null,
                              dropdownStyleData: _dropdownStyleData(context),
                              buttonStyleData: _buttonStyleData(),
                              menuItemStyleData: _menuItemStyleData(),
                            )
                    : Container(),
              ),
            ),
    );
  }
}

_text(context, title) {
  return Text(
    title ?? 'انتخاب کنید',
    style: TextStyle(
      fontSize: 13.5,
      color: darkMode.isTrue ? Colors.white : Colors.grey.shade800,
    ),
  );
}

// ignore: unused_element
_selectedItemBuilder(items, selectedItems) {
  return items.map((item) {
    return Container(
      alignment: AlignmentDirectional.center,
      child: Text(
        selectedItems.join(', '),
        style: const TextStyle(fontSize: 15.7, overflow: TextOverflow.ellipsis),
        maxLines: 1,
      ),
    );
  }).toList();
}

_dropdownStyleData(context) {
  return DropdownStyleData(
    isOverButton: true,
    maxHeight: Get.height * 0.6,
    width: Responsive.isMobile(context) ? Get.width - 20 : 200,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
  );
}

_buttonStyleData() {
  return ButtonStyleData(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    height: 50,
    width: 140,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
  );
}

_menuItemStyleData() {
  return const MenuItemStyleData(height: 50);
}
