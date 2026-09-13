import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/psbt_signing/public/psbt_signing_facade.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_key_summary.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_policy_panel.dart';

enum BullVaultSettingsPage { menu, selected, policy, keys }

class BullVaultSettingsScreen extends StatefulWidget {
  final String? walletId;
  final BullVaultSettingsPage page;
  const BullVaultSettingsScreen({
    super.key,
    this.walletId,
    this.page = BullVaultSettingsPage.menu,
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

  Future<void> _open(String route, {String? walletId}) async {
    await context.pushNamed(
      route,
      pathParameters: walletId == null ? const {} : {'walletId': walletId},
    );
    if (mounted) {
      await context.read<BullVaultSettingsCubit>().load(widget.walletId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (widget.page) {
        BullVaultSettingsPage.policy => context.loc.bullVaultViewPolicy,
        BullVaultSettingsPage.keys => context.loc.bullVaultViewKeys,
        _ => context.loc.bullVaultWalletLabel,
      }),
    ),
    body: SafeArea(
      child: BlocBuilder<BullVaultSettingsCubit, BullVaultSettingsState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (state.failure != null) ...[
                Text(context.loc.walletDetailsUnavailableLabel),
                TextButton(
                  onPressed: () => context.read<BullVaultSettingsCubit>().load(
                    widget.walletId,
                  ),
                  child: Text(context.loc.retry),
                ),
              ],
              if (widget.page == BullVaultSettingsPage.menu) ...[
                for (final record in state.records) ...[
                  _VaultCard(
                    record: record,
                    onTap: () => _open(
                      BullVaultFacade.settingsRouteName,
                      walletId: record.walletId,
                    ),
                  ),
                  const Gap(16),
                ],
                SettingsEntryItem(
                  icon: Icons.add,
                  title: context.loc.bullVaultCreateEntry,
                  onTap: () => _open(BullVaultFacade.createRouteName),
                ),
                SettingsEntryItem(
                  icon: Icons.restore_page_outlined,
                  title: context.loc.bullVaultRestoreEntry,
                  onTap: () => _open(BullVaultFacade.restoreRouteName),
                ),
                SettingsEntryItem(
                  icon: Icons.key_outlined,
                  title: context.loc.bullVaultUseBullAsSigner,
                  onTap: () => _open(SettingsRoute.signingKeyExport.name),
                ),
              ],
              if (state.inspection case final inspection?)
                ..._inspection(context, inspection),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _inspection(
    BuildContext context,
    BullVaultInspection inspection,
  ) {
    final wallet = inspection.wallet;
    if (widget.page == BullVaultSettingsPage.policy) {
      return [BullVaultPolicyPanel(inspection: inspection)];
    }
    if (widget.page == BullVaultSettingsPage.keys) {
      return [
        WalletKeysView(
          wallet: wallet,
          signerSummaryBuilder: (context, signer) =>
              _signer(context, inspection, signer),
        ),
      ];
    }
    return [
      _VaultCard(record: inspection.record),
      const Gap(24),
      SettingsEntryItem(
        icon: Icons.account_tree_outlined,
        title: context.loc.bullVaultViewPolicy,
        onTap: () =>
            _open(BullVaultFacade.policyRouteName, walletId: wallet.id),
      ),
      SettingsEntryItem(
        icon: Icons.key_outlined,
        title: context.loc.bullVaultViewKeys,
        onTap: () => _open(BullVaultFacade.keysRouteName, walletId: wallet.id),
      ),
      SettingsEntryItem(
        icon: Icons.backup_outlined,
        title: context.loc.bullVaultBackupRecovery,
        onTap: () =>
            _open(BullVaultFacade.backupRouteName, walletId: wallet.id),
      ),
      SettingsEntryItem(
        icon: Icons.update,
        title: context.loc.bullVaultRenew,
        onTap: () => _open(BullVaultFacade.renewRouteName, walletId: wallet.id),
      ),
      const Gap(24),
      SettingsEntryItem(
        icon: Icons.key,
        title: context.loc.bullVaultImportCosigner,
        onTap: () =>
            _open(BullVaultFacade.importCosignerRouteName, walletId: wallet.id),
      ),
      SettingsEntryItem(
        icon: Icons.devices,
        title: context.loc.bullVaultRegisterVault,
        onTap: () =>
            _open(SettingsRoute.walletRegistration.name, walletId: wallet.id),
      ),
      SettingsEntryItem(
        icon: Icons.draw_outlined,
        title: context.loc.psbtSigningTitle,
        onTap: () =>
            _open(const PsbtSigningFacade().routeName, walletId: wallet.id),
      ),
    ];
  }

  Widget _signer(
    BuildContext context,
    BullVaultInspection inspection,
    WalletSigner signer, {
    BitcoinPolicyKey? policyKey,
  }) => BullVaultKeySummary(
    inspection: inspection,
    signer: signer,
    policyKey: policyKey,
  );
}

class _VaultCard extends StatelessWidget {
  final BullVaultRecord record;
  final VoidCallback? onTap;
  const _VaultCard({required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final policy = record.recoveryPackage.policy;
    final id = record.walletId;
    final shortId = id.length <= 8 ? id : id.substring(0, 8);
    final dates = [
      ?policy.recoveryActivationTimestamp,
      ?policy.coldActivationTimestamp,
      ?policy.inheritanceActivationTimestamp,
      ?policy.lastResortActivationTimestamp,
    ]..sort();
    final expiry = dates.firstOrNull;
    String date(DateTime? value) => value == null
        ? context.loc.walletDetailsUnavailableLabel
        : MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: BullBorderedTile(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${context.loc.bullVaultWalletLabel} · $shortId',
                      style: context.font.titleLarge,
                    ),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              const Gap(16),
              Text(context.loc.bullVaultCreatedDate(date(policy.createdAt))),
              const Gap(8),
              Text(
                context.loc.bullVaultExpiryDate(
                  date(
                    expiry == null
                        ? null
                        : DateTime.fromMillisecondsSinceEpoch(
                            expiry * 1000,
                            isUtc: true,
                          ),
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
