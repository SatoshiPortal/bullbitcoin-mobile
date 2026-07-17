/// Capability port: hand inbound Trezor Suite callback URIs to the
/// underlying `trezor_connect` package so it can resolve the pending
/// Future by the URI's `id` query param.
///
/// Modeled as a non-repository port (it owns no data type, just a
/// transport-level forward) so the UI deeplink listener
/// (lib/features/trezor/ui/trezor_deeplink_listener.dart) doesn't
/// reach into the datasource directly.
abstract interface class TrezorCallbackPort {
  /// Hand a callback URI to Trezor Connect. The package looks up the
  /// pending Future by the URI's `id` query param and resolves it.
  void handleCallback(Uri uri);
}
