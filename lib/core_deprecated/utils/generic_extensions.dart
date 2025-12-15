extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

extension DateTimeExtension on DateTime {
  String toIso8601WithoutMilliseconds() => toIso8601String().substring(0, 19);
}
