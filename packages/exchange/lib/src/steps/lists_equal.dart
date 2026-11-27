/// Element-wise equality of two lists: the one helper behind the value
/// equality of the exchange's states, events and effects. With [nested],
/// elements that are lists themselves are compared the same way.
bool listsEqual(List<Object?> a, List<Object?> b, {bool nested = false}) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final (x, y) = (a[i], b[i]);
    if (nested && x is List<Object?> && y is List<Object?>) {
      if (!listsEqual(x, y, nested: true)) return false;
    } else if (x != y) {
      return false;
    }
  }
  return true;
}
