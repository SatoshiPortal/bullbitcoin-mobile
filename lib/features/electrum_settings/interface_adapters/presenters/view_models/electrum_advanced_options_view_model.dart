import 'package:freezed_annotation/freezed_annotation.dart';

part 'electrum_advanced_options_view_model.freezed.dart';

// Using freezed here for easy immutability since used in the UI and BLoC state
//  which makes re-rendering more efficient.
@freezed
sealed class ElectrumAdvancedOptionsViewModel
    with _$ElectrumAdvancedOptionsViewModel {
  // ElectrumEnvironment is not included here as it's not a setting the user can change
  // here since it is the settings for the specific environment the user is in.
  const factory ElectrumAdvancedOptionsViewModel({
    required int stopGap,
    required int timeout,
    required int retry,
    required bool validateDomain,
    String? socks5,
  }) = _ElectrumAdvancedOptionsViewModel;
  const ElectrumAdvancedOptionsViewModel._();
}
