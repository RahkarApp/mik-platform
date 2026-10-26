import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

// ignore: must_be_immutable
class KeyPad extends GetView {
  var output;
  int? length;
  bool? clear;
  KeyPad(
      {super.key,
      required this.output,
      required this.length,
      this.clear = false});
  var out = '';
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '3';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '3',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '2';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '2',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '1';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '1',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        )
      ]),
      const SizedBox(
        height: 10,
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '6';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '6',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '5';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '5',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '4';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '4',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        )
      ]),
      const SizedBox(
        height: 10,
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '9';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '9',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '8';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '8',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '7';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '7',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        )
      ]),
      const SizedBox(
        height: 10,
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        InkWell(
          onTap: () {
            if (out.isNotEmpty) {
              out = out.toString().substring(0, out.length - 1);
            }
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Icon(
                IconsaxPlusLinear.tag_cross,
                color: Colors.black,
              )),
        ),
        InkWell(
          onTap: () {
            if (out.length == length!) out = '';
            if (out.length < length!) out += '0';
            output(out);
          },
          borderRadius: BorderRadius.circular(50),
          child: CircleAvatar(
              maxRadius: 30,
              backgroundColor: Colors.grey.shade300.withValues(alpha: 0.7),
              child: const Text(
                '0',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black),
              )),
        ),
        clear!
            ? InkWell(
                onTap: () {
                  out = '';
                  output(out);
                },
                borderRadius: BorderRadius.circular(50),
                child: CircleAvatar(
                    maxRadius: 30,
                    backgroundColor:
                        Colors.grey.shade300.withValues(alpha: 0.7),
                    child: const Icon(
                      IconsaxPlusLinear.close_circle,
                      color: Colors.black,
                    )),
              )
            : const CircleAvatar(
                maxRadius: 30, backgroundColor: Colors.transparent)
      ]),
    ]);
  }
}
