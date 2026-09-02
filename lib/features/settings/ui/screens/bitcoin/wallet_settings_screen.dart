import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the SP setup flag on entry so the SP entry reflects a setup that
    // happened elsewhere (the settings cubit is a singleton).
    context.read<SettingsCubit>().checkSpWalletSetup();
  }

  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.loc.settingsWalletSettingsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final id in walletSettingsItemOrder)
                  items.byId(id).buildTile(context),
                for (final item in items.inSection(SettingsItemSection.wallet))
                  if (!walletSettingsItemOrder.contains(item.id))
                    item.buildTile(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
