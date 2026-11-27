/// A view's identifier. Knowing one is not a right to it: only the views an
/// authentication opened can be activated.
final class ViewId {
  final String value;

  const ViewId(this.value);

  @override
  bool operator ==(Object other) => other is ViewId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ViewId($value)';
}

/// What a session may know about a view it has opened. A view that was not
/// opened is never summarised, so neither its name nor its existence reaches a
/// caller that could not open it.
final class ViewSummary {
  final ViewId id;
  final String name;

  /// Whether the view requires a credential.
  final bool isProtected;

  /// Whether background sync may read the view's descriptors while locked.
  final bool backgroundEnabled;

  const ViewSummary({
    required this.id,
    required this.name,
    required this.isProtected,
    required this.backgroundEnabled,
  });
}
