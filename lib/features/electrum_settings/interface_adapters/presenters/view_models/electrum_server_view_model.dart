import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
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

  String get displayName {
    // Remove scheme if present (e.g., "ssl://" or "tcp://")
    if (url.contains('://')) {
      return url.split('://').last;
    }
    return url;
  }

  String get protocol {
    // Extract protocol if present (e.g., "ssl" or "tcp")
    if (url.contains('://')) {
      return url.split('://').first;
    }
    // Default to 'ssl' if no protocol specified, for Liquid servers that
    // don't require a scheme for example but always use SSL automatically.
    return 'ssl';
  }
}
