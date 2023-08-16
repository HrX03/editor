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
  final R _defaultValue;
  final SharedPreferencesType<T> _type;
  final String _key;
  final R Function(T value) _decode;
  final T Function(R value) _encode;

  SharedPreferencesNotifier({
    required R defaultValue,
    required SharedPreferencesType<T> type,
    required String key,
  })  : _key = key,
        _type = type,
        _defaultValue = defaultValue,
        _encode = ((v) => v as T),
        _decode = ((v) => v as R);

  SharedPreferencesNotifier.custom({
    required R defaultValue,
    required SharedPreferencesType<T> type,
    required String key,
    required T Function(R) encode,
    required R Function(T) decode,
  })  : _encode = encode,
        _decode = decode,
        _key = key,
        _type = type,
        _defaultValue = defaultValue;

  @override
  R build() {
    final prefValue = _get();
    return prefValue != null ? _decode(prefValue) : _defaultValue;
  }

  void set(R value) {
    _set(_encode(value));
    state = value;
  }

  T? _get() {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    return switch (_type) {
      SharedPreferencesType.boolean => sharedPreferences.getBool(_key),
      SharedPreferencesType.string => sharedPreferences.getString(_key),
      SharedPreferencesType.integer => sharedPreferences.getInt(_key),
      SharedPreferencesType.float => sharedPreferences.getDouble(_key),
      SharedPreferencesType.stringList => sharedPreferences.getStringList(_key),
    } as T?;
  }

  void _set(T value) {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    switch (_type) {
      case SharedPreferencesType.boolean:
        sharedPreferences.setBool(_key, value as bool);
      case SharedPreferencesType.string:
        sharedPreferences.setString(_key, value as String);
      case SharedPreferencesType.integer:
        sharedPreferences.setInt(_key, value as int);
      case SharedPreferencesType.float:
        sharedPreferences.setDouble(_key, value as double);
      case SharedPreferencesType.stringList:
        sharedPreferences.setStringList(_key, value as List<String>);
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
