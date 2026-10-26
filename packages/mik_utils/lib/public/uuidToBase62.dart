import 'dart:typed_data';

const _base62Chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

String uuidToBase62(String uuid) {
  final hex = uuid.replaceAll('-', '');
  final bytes = Uint8List(16);

  for (int i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }

  BigInt value = BigInt.zero;
  for (final b in bytes) {
    value = (value << 8) | BigInt.from(b);
  }

  final base = BigInt.from(62);
  final buffer = StringBuffer();

  while (value > BigInt.zero) {
    final mod = value % base;
    buffer.write(_base62Chars[mod.toInt()]);
    value = value ~/ base;
  }

  return buffer.toString().split('').reversed.join();
}
