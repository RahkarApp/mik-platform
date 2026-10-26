import 'package:flutter/material.dart';

// const Color dayColor = Color(0xFFfdfeff);
// const Color nigthColor = Color(0xFFfdfeff);
// const Color daySearchFillColor = Color(0xFFede3e3);
// const Color dayitemBackColor = Color.fromRGBO(224, 224, 224, 1);
// const Color nigthitemBackColor = Color.fromRGBO(117, 117, 117, 1);
// const Color purple = Color(0xFFb388eb);
// const Color yellowOriginal = Color(0xFFfcbf49);
// const Color green = Color(0xFF218380);
// const Color blue = Color(0xFF73D2DE);
// const Color orangeOriginal = Color(0xFFf77f00);
// const Color orange = Color(0xFFff6039);
// const Color yellow = Color(0xFFfff06b);
// const Color circleAvatarColor = Color.fromARGB(25, 179, 136, 235);

class AppColors {
  //ligth - //dark
  static Color get primary => const Color(0xFF7000ee);

  static Color get primaryLite => const Color(0xFF8542ff);

  static Color get primaryDark => const Color(0xFF6100cf);

  static Color get secondary => const Color(0xFFFF6039);

  static Color get boxBackground => primary.withValues(alpha: 0.1);

  static Color get moreBackground =>
      const Color(0xFF60391A).withValues(alpha: 0.1);

  static Color get disable => const Color(0xFFb1b1b1).withValues(alpha: 0.2);

  static Color get background => const Color(0xFFfdfeff);
  static Color get backgroundDarkMode => const Color(0xFF292d32);

  static Color get error => const Color(0xFFFF0E00);

  static Color get success => const Color(0xFF3DB15A);

  // static Color get orange =>
  //     darkMode.isFalse ? const Color(0xFFFF9F0A) : const Color(0xFFFF9F0A);

  static Color get yellowChart => const Color(0xFFFFF06B);

  static Color get yellow => const Color(0xFFF8CF00);
  static Color get orange => const Color(0xFFFF9F0A);

  static Color get blue => const Color(0xFF49A7FF);

  static Color get blueLite => const Color(0xFFB9D6FF);

  static Color get grey => const Color(0xFF8F8F8F);
}
