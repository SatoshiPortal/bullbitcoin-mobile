import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullAdvancedOptionsLink, BullSwitch;
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show RegtestHostProfile;
import 'package:settings/settings.dart'
    show SettingsLocalizations, SevenTapUnlocker;
import 'package:wizard/src/wizard_localizations_context.dart';

/// A pre-initialization choice; no application services are opened here.
class WizardNetworkControl extends StatefulWidget {
  const WizardNetworkControl({
    super.key,
    required this.logo,
    required this.onChanged,
    this.allowDeveloperNetwork = true,
    required this.onPrivacyChanged,
  });

  final ImageProvider logo;
  final ValueChanged<Environment?> onChanged;
  final bool allowDeveloperNetwork;
  final ValueChanged<bool?> onPrivacyChanged;

  @override
  State<WizardNetworkControl> createState() => _WizardNetworkControlState();
}

class _WizardNetworkControlState extends State<WizardNetworkControl>
    with AutomaticKeepAliveClientMixin {
  bool _unlocked = false;
  bool _consented = false;
  bool _screenPrivacy = true;
  Environment _network = Environment.mainnet;

  @override
  bool get wantKeepAlive => true;

  void _openAdvancedOptions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _WizardNetworkPage(
          network: _network,
          allowDeveloperNetwork: widget.allowDeveloperNetwork,
          screenPrivacy: _screenPrivacy,
          onPrivacyChanged: (value) {
            if (!mounted) return;
            setState(() => _screenPrivacy = value);
            widget.onPrivacyChanged(value);
          },
          consented: _consented,
          onChanged: (network, consented) {
            if (!mounted) return;
            setState(() {
              _network = network;
              _consented = consented;
            });
            widget.onChanged(network == Environment.mainnet ? null : network);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = SettingsLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SevenTapUnlocker(
          semanticsIdentifier: 'wizard.superuser.unlock',
          showMessage: false,
          tapsReachedMessage: _unlocked
              ? loc.settingsSuperuserModeDisabledMessage
              : loc.settingsSuperuserModeUnlockedMessage,
          onRequiredTaps: () {
            setState(() {
              _unlocked = !_unlocked;
              if (!_unlocked) {
                _consented = false;
                _network = Environment.mainnet;
                _screenPrivacy = true;
              }
            });
            if (!_unlocked) {
              widget.onChanged(null);
              widget.onPrivacyChanged(null);
            }
          },
          child: Image(image: widget.logo, width: 127, height: 127),
        ),
        if (_unlocked)
          Semantics(
            identifier: 'wizard.advanced_options',
            label: context.loc.wizardAdvancedOptionsTitle,
            button: true,
            onTap: _openAdvancedOptions,
            child: ExcludeSemantics(
              child: BullAdvancedOptionsLink(
                label: context.loc.wizardAdvancedOptionsTitle,
                color: context.appColors.onPrimaryFixed,
                onPressed: _openAdvancedOptions,
              ),
            ),
          ),
      ],
    );
  }
}

class _WizardNetworkPage extends StatefulWidget {
  const _WizardNetworkPage({
    required this.network,
    required this.allowDeveloperNetwork,
    required this.screenPrivacy,
    required this.onPrivacyChanged,
    required this.consented,
    required this.onChanged,
  });

  final Environment network;
  final bool allowDeveloperNetwork;
  final bool screenPrivacy;
  final ValueChanged<bool> onPrivacyChanged;
  final bool consented;
  final void Function(Environment, bool) onChanged;

  @override
  State<_WizardNetworkPage> createState() => _WizardNetworkPageState();
}

class _WizardNetworkPageState extends State<_WizardNetworkPage> {
  late Environment _network = widget.network;
  late bool _consented = widget.consented;
  late bool _screenPrivacy = widget.screenPrivacy;

  void _setScreenPrivacy(bool value) {
    setState(() => _screenPrivacy = value);
    widget.onPrivacyChanged(value);
  }

  Future<void> _select(Environment? network) async {
    if (network == null) return;
    if (network != Environment.mainnet && !_consented) {
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
      if (!mounted || accepted != true) return;
      _consented = true;
    }
    setState(() => _network = network);
    widget.onChanged(network, _consented);
  }

  @override
  Widget build(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.wizardAdvancedOptionsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                identifier: 'wizard.screen_privacy',
                label: loc.settingsScreenPrivacyTitle,
                toggled: _screenPrivacy,
                onTap: () => _setScreenPrivacy(!_screenPrivacy),
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: () => _setScreenPrivacy(!_screenPrivacy),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: Text(loc.settingsScreenPrivacyTitle)),
                          SizedBox(
                            width: 64,
                            height: 48,
                            child: Center(
                              child: BullSwitch(
                                value: _screenPrivacy,
                                onChanged: _setScreenPrivacy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.allowDeveloperNetwork)
                Semantics(
                  identifier: 'wizard.network.selector',
                  label: loc.networkSelectorTitle,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (network, label) in [
                        (Environment.mainnet, loc.electrumMainnet),
                        (Environment.testnet, loc.electrumTestnet),
                        if (RegtestHostProfile.isConfigured)
                          (Environment.regtest, loc.electrumRegtest),
                      ])
                        Semantics(
                          identifier: 'wizard.network.${network.name}',
                          label: label,
                          button: true,
                          selected: _network == network,
                          onTap: () => _select(network),
                          child: ExcludeSemantics(
                            child: ListTile(
                              title: Text(label),
                              selected: _network == network,
                              trailing: _network == network
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => _select(network),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
