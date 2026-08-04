import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_server_view_model.freezed.dart';

// Using freezed here for easy immutability since used in the UI and BLoC state
//  which makes re-rendering more efficient.
@freezed
sealed class ElectrumServerViewModel with _$ElectrumServerViewModel {
  const factory ElectrumServerViewModel({
    required String url,
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
}
