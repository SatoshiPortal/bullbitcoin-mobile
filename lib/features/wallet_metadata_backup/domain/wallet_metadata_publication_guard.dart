final class WalletMetadataPublicationSuppression {
  void Function()? _release;

  WalletMetadataPublicationSuppression._(this._release);

  bool get isClosed => _release == null;

  void close() {
    final release = _release;
    if (release == null) return;
    _release = null;
    release();
  }
}

final class WalletMetadataPublicationGuard {
  var _publicationSuppressionDepth = 0;
  var _ignoredChangeDepth = 0;

  bool get isPublicationSuppressed => _publicationSuppressionDepth > 0;
  bool get ignoresOwnerChanges => _ignoredChangeDepth > 0;

  WalletMetadataPublicationSuppression beginPublicationSuppression({
    void Function()? onReleased,
  }) {
    _publicationSuppressionDepth++;
    return WalletMetadataPublicationSuppression._(() {
      _publicationSuppressionDepth--;
      onReleased?.call();
    });
  }

  Future<T> suppressApplyChangesWhile<T>(Future<T> Function() action) async {
    _publicationSuppressionDepth++;
    _ignoredChangeDepth++;
    try {
      return await action();
    } finally {
      _ignoredChangeDepth--;
      _publicationSuppressionDepth--;
    }
  }
}
