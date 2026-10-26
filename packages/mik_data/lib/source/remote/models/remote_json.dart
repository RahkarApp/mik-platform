class RemoteJson {
  final Map<String, dynamic> value;
  RemoteJson(Object? data)
    : value = data is Map<String, dynamic>
          ? data
          : throw const FormatException('Invalid server object');
  String text(String key) {
    final field = value[key];
    if (field is! String || field.isEmpty) {
      throw FormatException('Invalid $key');
    }
    return field;
  }

  String? optionalText(String key) => value[key] == null ? null : text(key);
  int number(String key) {
    final field = value[key];
    if (field is! int) throw FormatException('Invalid $key');
    return field;
  }

  int? optionalNumber(String key) => value[key] == null ? null : number(key);
  bool flag(String key) {
    final field = value[key];
    if (field is! bool) throw FormatException('Invalid $key');
    return field;
  }

  List<T> items<T>(String key, T Function(Object?) parse) {
    final field = value[key];
    if (field is! List) throw FormatException('Invalid $key');
    return List.unmodifiable(field.map(parse));
  }

  List<String> strings(String key) => items(key, (v) {
    if (v is! String || v.isEmpty) throw FormatException('Invalid $key');
    return v;
  });
}
