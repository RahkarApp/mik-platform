import 'package:persian_tools/persian_tools.dart' as tools;

class Number {
  static String addCommas(number) {
    if ((number.toString().contains('.') && number.toString().split('.')[1] == '0')) {
      number = int.parse(number.toStringAsFixed(0));
    }
    return tools.addCommas(number ?? '');
  }

  static financial(num number) {
    if (number < 0) return '${addCommas(number * -1)} بدهکار';
    if (number > 0) return '${addCommas(number)} طلب‌کار';
    if (number == 0) return 'تسویه';
  }

  static financialWithoutNumber(num number) {
    if (number < 0) return 'بدهکار';
    if (number > 0) return 'طلب‌کار';
    if (number == 0) return 'تسویه';
  }

  static numberPlus(num number) {
    if (number < 0) return addCommas(number * -1);
    if (number > 0) return addCommas(number);
    if (number == 0) return '';
  }
}
