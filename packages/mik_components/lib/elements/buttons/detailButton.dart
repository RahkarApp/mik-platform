// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class DBTN {
  static Widget typeOne({
    required String title,
    required String subtitle,
    required String text,
    required String btntext,
    required onTap,
    required Color color,
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.topRight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: text.toString().length < 6 ? 35 : 25,
                fontWeight: FontWeight.w800,
                fontFamily: 'iran',
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: double.minPositive),
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      btntext,
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    Icon(
                      IconsaxPlusLinear.arrow_left_1,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget typeTwo({
    required String title,
    required String text,
    required onTap,
    required Color color,
    required double height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1,
                  color: Colors.white,
                  fontSize: text.toString().length < 6 ? 35 : 25,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'iran',
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_1,
              color: Colors.white.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}
