sealed class Value<T> {
  final T? value;

  const factory Value(T value) = _ConcreteValue;
  const factory Value.erase() = _EraseValue;

  const Value._(this.value);

  static T? handleValue<T>(Value<T?>? value, T? defaultValue, [T? classValue]) {
    if (value == null) return classValue;
    if (value is _EraseValue) return defaultValue;
    return value.value;
  }
}

class _ConcreteValue<T> extends Value<T> {
  const _ConcreteValue(T super.value) : super._();
}

class _EraseValue<T> extends Value<T> {
  const _EraseValue() : super._(null);
}
