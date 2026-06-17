/// Dispatches inbound Trezor Suite callback URIs to the underlying
/// Trezor Connect package.
///
/// Lives in domain/repositories/ so the UI deeplink listener
/// (lib/features/trezor/ui/trezor_deeplink_listener.dart) doesn't
/// reach into the data datasource — UI depends on this contract,
/// the impl in data/ wraps the datasource.
abstract interface class TrezorCallbackDispatcher {
  /// Hand a callback URI to Trezor Connect. The package looks up the
  /// pending Future by the URI's `id` query param and resolves it.
  void handleCallback(Uri uri);
}
