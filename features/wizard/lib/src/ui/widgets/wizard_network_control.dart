import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPickerChip, BullPickerItem, BullSettingsEntryItem, BullSwitch;
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show RegtestHostProfile;
import 'package:settings/settings.dart'
    show SettingsLocalizations, SevenTapUnlocker;

/// The welcome logo, whose seven taps toggle the superuser mode.
///
/// The unlocked state lives in the wizard screen, which shows the extra rows
/// of [WizardSuperuserOptions] on the settings step.
class WizardNetworkControl extends StatelessWidget {
  const WizardNetworkControl({
    super.key,
    required this.logo,
    required this.unlocked,
    required this.onToggled,
  });

  final ImageProvider logo;
  final bool unlocked;

  /// Fired when the seven taps are reached, to unlock or lock again.
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    return SevenTapUnlocker(
      semanticsIdentifier: 'wizard.superuser.unlock',
      tapsReachedMessage: unlocked
          ? loc.settingsSuperuserModeDisabledMessage
          : loc.settingsSuperuserModeUnlockedMessage,
      onRequiredTaps: onToggled,
      child: Image(image: logo, width: 127, height: 127),
    );
  }
}

/// Asks before leaving mainnet; true when the user accepts the risk.
Future<bool> confirmDeveloperNetwork(BuildContext context) async {
  final loc = SettingsLocalizations.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(loc.settingsDevModeWarningTitle),
      content: Text(loc.settingsDevModeWarningMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(loc.settingsDevModeUnderstandButton),
        ),
      ],
    ),
  );
  return accepted == true;
}

/// The Screen Privacy and Network rows appended to the settings step once the
/// superuser mode is unlocked. A pre-initialization choice; no application
/// services are opened here.
class WizardSuperuserOptions extends StatelessWidget {
  const WizardSuperuserOptions({
    super.key,
    required this.screenPrivacy,
    required this.onScreenPrivacyPicked,
    required this.network,
    required this.onNetworkPicked,
    required this.allowDeveloperNetwork,
  });

  final bool screenPrivacy;
  final ValueChanged<bool> onScreenPrivacyPicked;
  final Environment network;
  final ValueChanged<Environment> onNetworkPicked;

  /// Hides the network row where the build does not allow another network.
  final bool allowDeveloperNetwork;

  @override
  Widget build(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    final divider = Divider(height: 1, color: context.appColors.border);
    return Column(
      children: [
        divider,
        MergeSemantics(
          child: Semantics(
            identifier: 'wizard.screen_privacy',
            child: BullSettingsEntryItem(
              icon: Icons.visibility_off_outlined,
              title: loc.settingsScreenPrivacyTitle,
              contentPadding: EdgeInsets.zero,
              trailing: BullSwitch(
                value: screenPrivacy,
                onChanged: onScreenPrivacyPicked,
              ),
            ),
          ),
        ),
        if (allowDeveloperNetwork) ...[
          divider,
          Semantics(
            identifier: 'wizard.network.selector',
            child: BullSettingsEntryItem(
              icon: Icons.lan_outlined,
              title: loc.networkSelectorTitle,
              contentPadding: EdgeInsets.zero,
              trailing: BullPickerChip<Environment>(
                tooltip: loc.networkSelectorTitle,
                value: network,
                items: [
                  BullPickerItem(
                    value: Environment.mainnet,
                    label: loc.electrumMainnet,
                  ),
                  BullPickerItem(
                    value: Environment.testnet,
                    label: loc.electrumTestnet,
                  ),
                  if (RegtestHostProfile.isConfigured)
                    BullPickerItem(
                      value: Environment.regtest,
                      label: loc.electrumRegtest,
                    ),
                ],
                onChanged: onNetworkPicked,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
