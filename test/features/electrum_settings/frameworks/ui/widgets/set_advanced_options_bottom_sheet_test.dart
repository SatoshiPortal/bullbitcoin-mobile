import 'package:bb_mobile/features/electrum_settings/frameworks/ui/widgets/set_advanced_options_bottom_sheet.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows Tor only for an active custom Bitcoin onion', () {
    expect(
      shouldShowTorInAdvancedOptions(
        const ElectrumSettingsState(hasActiveCustomBitcoinOnionServer: true),
      ),
      isTrue,
    );
    expect(
      shouldShowTorInAdvancedOptions(
        const ElectrumSettingsState(hasActiveCustomBitcoinOnionServer: false),
      ),
      isFalse,
    );
    expect(
      shouldShowTorInAdvancedOptions(
        const ElectrumSettingsState(
          isLiquid: true,
          hasActiveCustomBitcoinOnionServer: true,
        ),
      ),
      isFalse,
    );
  });
}
