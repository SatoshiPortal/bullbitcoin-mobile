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
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url; // Fallback to the raw URL if parsing fails
    }

    // Display without the scheme
    return uri.host + (uri.hasPort ? ':${uri.port}' : '');
  }
}
