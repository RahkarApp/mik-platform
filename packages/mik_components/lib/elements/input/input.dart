// ignore_for_file: annotate_overrides, prefer_typing_uninitialized_variables

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mik_consts/colors.dart';
import 'package:mik_variables/variable.dart';
import 'package:mik_utils/public/Stringwidth.dart';

// ignore: must_be_immutable
class Input extends StatefulWidget {
  TextEditingController controller;
  FocusNode? focusNode;
  FocusNode? nextFocus;
  List<TextInputFormatter>? inputFormatters;
  TextInputType? keyboardType;
  TextInputAction? textInputAction;
  Iterable<String>? autofillHints;
  ValueChanged<String>? onSubmitted;
  String name;
  TextDirection? textDirection;
  TextAlign? textAlign;
  Color? fillColor;
  bool? readOnly;
  int? maxLines;
  int? minLines;
  int? maxLength;
  bool? enabled;
  bool? require;
  bool? inDropDown;
  int? style;
  dynamic onChanged;
  dynamic onTap;
  String? hintText;
  double? rightPadding;
  EdgeInsets? padding;
  Widget? suffixIcon;
  bool autoFocus = false;
  // String? desc;
  Input({
    super.key,
    required this.controller,
    this.style,
    this.fillColor,
    this.rightPadding,
    this.suffixIcon,
    this.focusNode,
    this.nextFocus,
    this.require,
    this.padding,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.inputFormatters,
    this.keyboardType,
    this.textDirection,
    this.textAlign,
    this.readOnly,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.inDropDown = false,
    this.enabled,
    this.hintText,
    this.autoFocus = false,

    //this.desc,
    required this.name,
  });

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  late FocusNode fcs;

  initState() {
    super.initState();
    fcs = FocusNode();
  }

  Color get styleTwoFill {
    // Observe the mode even with a custom fill so Obx can keep theme changes live.
    final isDark = darkMode.value;
    return widget.fillColor ??
        (isDark ? Colors.grey.shade700 : Colors.grey.shade200);
  }

  Color get styleTwoForeground =>
      ThemeData.estimateBrightnessForColor(styleTwoFill) == Brightness.dark
      ? Colors.white
      : Colors.grey.shade800;

  double labelWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text:
            '${widget.name}${widget.name.isEmpty ? '' : ':'}${widget.require == true ? ' *' : ''}',
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13.5),
      ),
      textDirection: widget.textDirection ?? TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + 8;
    painter.dispose();
    return width > Get.width / 5 ? width : Get.width / 5;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding:
            widget.padding ??
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Stack(
          alignment:
              (widget.textDirection ?? TextDirection.rtl) == TextDirection.rtl
              ? Alignment.topRight
              : Alignment.topLeft,
          children: <Widget>[
            if (widget.style != 2)
              (widget.inDropDown ?? false)
                  ? child()
                  : (widget.enabled ?? true)
                  ? InkWell(
                      onTap: () => {
                        if (widget.onTap != null) widget.onTap(),
                        (widget.focusNode ?? fcs).requestFocus(),
                      },
                      child: child(),
                    )
                  : child(),
            TextFormField(
              autofillHints: widget.autofillHints,
              autofocus: widget.autoFocus,
              controller: widget.controller,
              focusNode: widget.focusNode ?? fcs,
              onFieldSubmitted: (value) {
                widget.nextFocus?.requestFocus();
                widget.onSubmitted?.call(value);
              },
              inputFormatters: widget.inputFormatters ?? [],
              textInputAction: widget.nextFocus != null
                  ? TextInputAction.next
                  : widget.textInputAction,
              style: TextStyle(
                color: widget.style == 2
                    ? styleTwoForeground
                    : darkMode.isTrue
                    ? Colors.white
                    : Colors.grey.shade800,
              ),
              decoration: (widget.style == null || widget.style == 1)
                  ? InputDecoration(
                      fillColor:
                          widget.fillColor ??
                          (darkMode.isFalse
                              ? Colors.white
                              : Colors.grey.shade300),
                      // filled: true,
                      isDense: true,
                      hintText: widget.hintText,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 12.0,
                      ),
                      suffixIcon: widget.suffixIcon,
                      suffixIconConstraints: const BoxConstraints(
                        maxHeight: 20,
                      ),
                      prefix: SizedBox(
                        width: !(widget.require ?? false)
                            ? StringChecker.width(widget.name) +
                                  (kIsWeb ? 20 : 0)
                            : StringChecker.width(widget.name) +
                                  (kIsWeb ? 35 : 15),
                        //name.length *
                        //  8, //rightPadding ?? Get.width / 5,
                        child: const Row(
                          children: [
                            // Text(name, style: const TextStyle(fontSize: 16)),
                            // if (require ?? false)
                            //   Container(
                            //       padding: const EdgeInsets.only(right: 3),
                            //       // alignment: Alignment.topRight,
                            //       child: const Text(
                            //         '*',
                            //         style: TextStyle(
                            //             color: Colors.red,
                            //             fontSize: 16,
                            //             fontWeight: FontWeight.bold),
                            //       )),
                          ],
                        ),
                      ),
                      counter: Container(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: darkMode.isTrue
                              ? (darkMode.value
                                        ? AppColors.background
                                        : AppColors.backgroundDarkMode)
                                    .withValues(alpha: 0.6)
                              : AppColors.backgroundDarkMode.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                      disabledBorder: widget.inDropDown ?? false
                          ? UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: darkMode.isTrue
                                    ? AppColors.background.withValues(
                                        alpha: 0.6,
                                      )
                                    : AppColors.backgroundDarkMode.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            )
                          : null,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    )
                  : InputDecoration(
                      fillColor: widget.style == 2
                          ? styleTwoFill
                          : widget.fillColor ??
                                (darkMode.isFalse
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade700),
                      filled: true,
                      isDense: true,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: widget.style == 2
                            ? styleTwoForeground.withValues(alpha: 0.6)
                            : darkMode.isTrue
                            ? (darkMode.value
                                      ? AppColors.background
                                      : AppColors.backgroundDarkMode)
                                  .withValues(alpha: 0.5)
                            : AppColors.backgroundDarkMode.withValues(
                                alpha: 0.5,
                              ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12.0,
                      ),
                      suffixIcon: widget.suffixIcon,
                      suffixIconConstraints: const BoxConstraints(
                        maxHeight: 20,
                      ),
                      prefix: SizedBox(
                        width:
                            widget.rightPadding ??
                            (widget.style == 2
                                ? labelWidth(context)
                                : Get.width / 5),
                        child: const Row(
                          children: [
                            // Text(name, style: const TextStyle(fontSize: 16)),
                            // if (require ?? false)
                            //   Container(
                            //       padding: const EdgeInsets.only(right: 3),
                            //       // alignment: Alignment.topRight,
                            //       child: const Text(
                            //         '*',
                            //         style: TextStyle(
                            //             color: Colors.red,
                            //             fontSize: 16,
                            //             fontWeight: FontWeight.bold),
                            //       )),
                          ],
                        ),
                      ),
                      counter: Container(),
                      disabledBorder: widget.inDropDown ?? false
                          ? OutlineInputBorder(
                              borderSide: const BorderSide(
                                style: BorderStyle.none,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(style: BorderStyle.none),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
              textDirection: widget.textDirection ?? TextDirection.rtl,
              textAlign: widget.textAlign ?? TextAlign.start,
              readOnly: widget.readOnly ?? false,
              maxLines: widget.maxLines ?? 1,
              minLines: widget.maxLines ?? 1,
              maxLength: widget.maxLength,
              onChanged: (v) =>
                  widget.onChanged != null ? widget.onChanged(v) : {},
              onTap: widget.onTap,
              enabled: (widget.enabled ?? true),
              keyboardType: widget.keyboardType,
            ),
            // Filled fields paint an opaque background; their label belongs above it.
            // IgnorePointer keeps tapping the label focused on the real text field.
            if (widget.style == 2) IgnorePointer(child: child()),
          ],
        ),
      ),
    );
  }

  Widget child() {
    return Container(
      padding: EdgeInsets.only(
        top: 10,
        right: (widget.textDirection ?? TextDirection.rtl) == TextDirection.rtl
            ? 12
            : 0,
        left: (widget.textDirection ?? TextDirection.rtl) == TextDirection.rtl
            ? 0
            : 12,
        bottom: 8,
      ),
      child: Row(
        textDirection: widget.style == 2
            ? widget.textDirection ?? TextDirection.rtl
            : null,
        children: [
          if (widget.name.isNotEmpty)
            Text(
              '${widget.name}:',
              style: TextStyle(
                fontSize: 13.5,
                color: widget.style == 2 ? styleTwoForeground : null,
              ),
            ),
          if (widget.require ?? false)
            Container(
              padding: const EdgeInsets.only(right: 3),
              // alignment: Alignment.topRight,
              child: const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  // fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
