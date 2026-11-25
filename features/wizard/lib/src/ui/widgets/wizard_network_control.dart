import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullAdvancedOptionsLink;
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
  });

  final ImageProvider logo;
  final ValueChanged<Environment?> onChanged;

  @override
  State<WizardNetworkControl> createState() => _WizardNetworkControlState();
}

class _WizardNetworkControlState extends State<WizardNetworkControl>
    with AutomaticKeepAliveClientMixin {
  bool _unlocked = false;
  bool _consented = false;
  Environment _network = Environment.mainnet;

  @override
  bool get wantKeepAlive => true;

  void _openAdvancedOptions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _WizardNetworkPage(
          network: _network,
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
              }
            });
            if (!_unlocked) widget.onChanged(null);
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
    required this.consented,
    required this.onChanged,
  });

  final Environment network;
  final bool consented;
  final void Function(Environment, bool) onChanged;

  @override
  State<_WizardNetworkPage> createState() => _WizardNetworkPageState();
}

class _WizardNetworkPageState extends State<_WizardNetworkPage> {
  late Environment _network = widget.network;
  late bool _consented = widget.consented;

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
        child: Semantics(
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
      ),
    );
  }
}
