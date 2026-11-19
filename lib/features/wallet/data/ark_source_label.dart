/// A presentation-only label already read by source selection; never a read gate.
final class ArkSourceLabelCache {
  ({String walletId, String? label})? _current;

  void observe(String walletId, String? label) =>
      _current = (walletId: walletId, label: label);

  String? read(String walletId) {
    final current = _current;
    return current?.walletId == walletId ? current?.label : null;
  }
}

/// Optional lookup failures cannot retire a valid balance or financial readiness.
String? optionalArkSourceLabel(
  String walletId,
  String? Function(String)? lookup,
) {
  try {
    final label = lookup?.call(walletId)?.trim();
    return label == null || label.isEmpty ? null : label;
  } on Exception {
    return null;
  }
}
