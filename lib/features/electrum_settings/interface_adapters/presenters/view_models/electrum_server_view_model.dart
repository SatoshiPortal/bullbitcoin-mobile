import 'package:electrum/electrum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_view_model.freezed.dart';

// Using freezed here for easy immutability since used in the UI and BLoC state
//  which makes re-rendering more efficient.
@freezed
sealed class ElectrumServerViewModel with _$ElectrumServerViewModel {
  const factory ElectrumServerViewModel({
    required String url,
    required ElectrumServerNetwork network,
    required ElectrumServerStatus status,
    required int priority,
  }) = _ElectrumServerViewModel;
  const ElectrumServerViewModel._();

  ElectrumServerUrl get _address => ElectrumServerUrl(url);

  /// Address without the scheme (e.g. `ssl://` or `tcp://`).
  String get displayName => _address.authority;

  /// Configured protocol, defaulting to `ssl` for entries that omit it —
  /// Liquid servers, for example, are always TLS without saying so.
  String get protocol => _address.scheme;

  bool get isOnion => _address.isOnion;

  /// Whether the connection is encrypted end to end: TLS, or an onion service
  /// (Tor encrypts it even when the scheme is plain `tcp://`).
  bool get isEncrypted => protocol == 'ssl' || isOnion;
}
