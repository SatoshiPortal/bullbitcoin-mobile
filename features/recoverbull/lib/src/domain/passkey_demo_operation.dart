/// A ceremony is invalidated permanently when its page closes or access ends.
final class PasskeyDemoOperation {
  final Future<bool> Function() _enabled;
  bool _cancelled = false;
  void Function()? _onCancel;

  PasskeyDemoOperation(this._enabled);

  bool get isCancelled => _cancelled;

  void onCancel(void Function()? callback) {
    _onCancel = callback;
    if (_cancelled) callback?.call();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call();
    _onCancel = null;
  }

  Future<bool> isAllowed() async {
    if (_cancelled) return false;
    final enabled = await _enabled();
    if (!enabled) cancel();
    return enabled && !_cancelled;
  }
}
