/// Dispatches inbound Trezor Suite callback URIs to the underlying
/// Trezor Connect package.
///
/// Exists at the application layer so the UI deeplink listener
/// (lib/features/trezor/ui/trezor_deeplink_listener.dart) doesn't
/// reach into the framework datasource — UI depends on this port,
/// adapter wraps the datasource.
abstract class TrezorCallbackDispatcher {
  /// Hand a callback URI to Trezor Connect. The package looks up the
  /// pending Future by the URI's `id` query param and resolves it.
  void handleCallback(Uri uri);
}
