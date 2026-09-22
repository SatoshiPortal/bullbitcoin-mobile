import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_account_key.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_card.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_key_summary.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_policy_panel.dart';
import 'package:bb_mobile/features/psbt_signing/public/psbt_signing_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum BullVaultSettingsPage { selected, policy, keys }

class BullVaultSettingsScreen extends StatefulWidget {
  final String walletId;
  final BullVaultSettingsPage page;
  const BullVaultSettingsScreen({
    super.key,
    required this.walletId,
    this.page = BullVaultSettingsPage.selected,
  });
  @override
  State<BullVaultSettingsScreen> createState() =>
      _BullVaultSettingsScreenState();
}

class _BullVaultSettingsScreenState extends State<BullVaultSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<BullVaultSettingsCubit>().load(widget.walletId);
    }
  }

  Future<void> _open(String route, {Object? extra}) async {
    await context.pushNamed(
      route,
      pathParameters: {'walletId': widget.walletId},
      extra: extra,
    );
    if (mounted) {
      await context.read<BullVaultSettingsCubit>().load(widget.walletId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.page) {
        BullVaultSettingsPage.selected => context.loc.bullVaultWalletLabel,
        BullVaultSettingsPage.policy => context.loc.bullVaultViewPolicy,
        BullVaultSettingsPage.keys => context.loc.bullVaultViewKeys,
      }),
    ),
    body: SafeArea(
      child: BlocBuilder<BullVaultSettingsCubit, BullVaultSettingsState>(
        builder: (context, state) => switch (state) {
          BullVaultSettingsLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          BullVaultInspectionLoaded(:final inspection) => ListView(
            padding: const EdgeInsets.all(24),
            children: _content(inspection),
          ),
          BullVaultSettingsFailed() || BullVaultMenuLoaded() => Column(
            children: [
              Text(context.loc.walletDetailsUnavailableLabel),
              TextButton(
                onPressed: () => context.read<BullVaultSettingsCubit>().load(
                  widget.walletId,
                ),
                child: Text(context.loc.retry),
              ),
            ],
          ),
        },
      ),
    ),
  );
  List<Widget> _content(BullVaultInspection inspection) =>
      switch (widget.page) {
        BullVaultSettingsPage.policy => [
          BullVaultPolicyPanel(inspection: inspection),
        ],
        BullVaultSettingsPage.keys => [
          WalletKeysView(
            wallet: inspection.wallet,
            signerSummaryBuilder: (context, signer) =>
                BullVaultKeySummary(inspection: inspection, signer: signer),
            accountKeyBuilder: (context, key) =>
                BullVaultAccountKey(accountKey: key),
            onSignerDeviceUpdated: () =>
                context.read<BullVaultSettingsCubit>().load(widget.walletId),
          ),
        ],
        BullVaultSettingsPage.selected => [
          BullVaultCard(record: inspection.record),
          const Gap(24),
          SettingsEntryItem(
            icon: Icons.account_tree_outlined,
            title: context.loc.bullVaultViewPolicy,
            onTap: () => _open(BullVaultFacade.policyRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.key_outlined,
            title: context.loc.bullVaultViewKeys,
            onTap: () => _open(BullVaultFacade.keysRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.backup_outlined,
            title: context.loc.bullVaultBackupRecovery,
            onTap: () => _open(BullVaultFacade.backupRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.update,
            title: context.loc.bullVaultRenew,
            onTap: () => _open(
              BullVaultFacade.renewRouteName,
              extra: inspection.wallet.displayLabel(context),
            ),
          ),
          const Gap(24),
          SettingsEntryItem(
            icon: Icons.key,
            title: context.loc.bullVaultImportCosigner,
            onTap: () => _open(BullVaultFacade.cosignerRouteName),
          ),
          SettingsEntryItem(
            icon: Icons.devices,
            title: context.loc.bullVaultRegisterVault,
            onTap: () => _open(
              SettingsRoute.walletRegistration.name,
              extra: WalletRegistrationRequest(wallet: inspection.wallet),
            ),
          ),
          SettingsEntryItem(
            icon: Icons.draw_outlined,
            title: context.loc.psbtSigningTitle,
            onTap: () => _open(const PsbtSigningFacade().routeName),
          ),
        ],
      };
}
