import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef PrefNotifier<R, T>
    = NotifierProvider<SharedPreferencesNotifier<R, T>, R>;

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final themeModeProvider = PrefNotifier<ThemeMode, String>(
  () => SharedPreferencesNotifier.custom(
    defaultValue: ThemeMode.light,
    key: "theme_mode",
    type: SharedPreferencesType.string,
    encode: (value) => value.name,
    decode: (value) => ThemeMode.values.byName(value),
  ),
);

final enableLineNumberColumnProvider = PrefNotifier<bool, bool>(
  () => SharedPreferencesNotifier(
    defaultValue: true,
    key: "enable_line_number_column",
    type: SharedPreferencesType.boolean,
  ),
);

final enableLineHighlightingProvider = PrefNotifier<bool, bool>(
  () => SharedPreferencesNotifier(
    defaultValue: true,
    key: "enable_line_highlighting",
    type: SharedPreferencesType.boolean,
  ),
);

class SharedPreferencesNotifier<R, T> extends Notifier<R> {
  final R defaultValue;
  final SharedPreferencesType<T> type;
  final String key;
  final R Function(T value) decode;
  final T Function(R value) encode;

  SharedPreferencesNotifier({
    required this.defaultValue,
    required this.type,
    required this.key,
  })  : encode = ((v) => v as T),
        decode = ((v) => v as R);

  SharedPreferencesNotifier.custom({
    required this.defaultValue,
    required this.type,
    required this.key,
    required this.encode,
    required this.decode,
  });

  @override
  R build() {
    final prefValue = _get();
    return prefValue != null ? decode(prefValue) : defaultValue;
  }

  void set(R value) {
    _set(encode(value));
    state = value;
  }

  T? _get() {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    return switch (type) {
      SharedPreferencesType.boolean => sharedPreferences.getBool(key),
      SharedPreferencesType.string => sharedPreferences.getString(key),
      SharedPreferencesType.integer => sharedPreferences.getInt(key),
      SharedPreferencesType.float => sharedPreferences.getDouble(key),
      SharedPreferencesType.stringList => sharedPreferences.getStringList(key),
    } as T?;
  }

  void _set(T value) {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    switch (type) {
      case SharedPreferencesType.boolean:
        sharedPreferences.setBool(key, value as bool);
      case SharedPreferencesType.string:
        sharedPreferences.setString(key, value as String);
      case SharedPreferencesType.integer:
        sharedPreferences.setInt(key, value as int);
      case SharedPreferencesType.float:
        sharedPreferences.setDouble(key, value as double);
      case SharedPreferencesType.stringList:
        sharedPreferences.setStringList(key, value as List<String>);
    }
  }
}

enum SharedPreferencesType<T> {
  boolean<bool>(),
  string<String>(),
  integer<int>(),
  float<double>(),
  stringList<List<String>>(),
}
