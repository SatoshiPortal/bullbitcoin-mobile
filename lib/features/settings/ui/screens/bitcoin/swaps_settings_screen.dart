import 'package:bb_mobile/core/swaps/swap_mode_setting_repository.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/ui/settings_router.dart';
import 'package:bb_mobile/features/settings/ui/widgets/swap_server_dialog.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SwapsSettingsScreen extends StatelessWidget {
  const SwapsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.swapsSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SettingsEntryItem(
                  icon: Icons.handshake,
                  title: context.loc.swapsTrustedModeTitle,
                  subtitle: context.loc.swapsTrustedModeSubtitle,
                  trailing: const _TrustedSwapsSwitch(),
                ),
                SettingsEntryItem(
                  icon: Icons.swap_vertical_circle,
                  title: context.loc.autoswapSettingsTitle,
                  onTap: () =>
                      context.pushNamed(SettingsRoute.autoswapSettings.name),
                ),
                SettingsEntryItem(
                  icon: Icons.restore,
                  title: context.loc.swapRestoreTitle,
                  onTap: () =>
                      context.pushNamed(SettingsRoute.swapRestore.name),
                ),
                SettingsEntryItem(
                  icon: Icons.swap_calls,
                  title: context.loc.swapServerTitle,
                  onTap: () => showSwapServerDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustedSwapsSwitch extends StatefulWidget {
  const _TrustedSwapsSwitch();

  @override
  State<_TrustedSwapsSwitch> createState() => _TrustedSwapsSwitchState();
}

class _TrustedSwapsSwitchState extends State<_TrustedSwapsSwitch> {
  final SwapModeSettingRepository _repository =
      locator<SwapModeSettingRepository>();
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _repository.isTrustedEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await _repository.setTrustedEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    if (enabled == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Switch(value: enabled, onChanged: _toggle);
  }
}
