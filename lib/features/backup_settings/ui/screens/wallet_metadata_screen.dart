import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WalletMetadataScreen extends StatelessWidget {
  final WalletBackupContents contents;

  const WalletMetadataScreen({super.key, required this.contents});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.walletBackupMetadataTitle,
          onBack: context.pop,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              context.loc.walletBackupMetadataDescription,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            _CountCard(
              icon: Icons.sell_outlined,
              title: context.loc.walletBackupMetadataLabels,
              count: contents.labelCount,
            ),
            _CountCard(
              icon: Icons.ac_unit,
              title: context.loc.walletBackupMetadataFrozenCoins,
              count: contents.frozenCoinCount,
            ),
            _CountCard(
              icon: Icons.tune,
              title: context.loc.walletBackupMetadataPreferences,
              count: contents.walletPreferenceCount,
            ),
            if (contents.settings case final settings?) ...[
              const Gap(16),
              _SettingsCard(
                title: context.loc.walletBackupMetadataAppSettings,
                value: _appSettings(context, settings),
              ),
              _SettingsCard(
                title: context.loc.autoswapSettingsTitle,
                value: _autoswapSettings(context, settings.autoswap),
              ),
              _SettingsCard(
                title: context.loc.bitcoinSettingsElectrumServerTitle,
                value: _electrumSettings(context, settings),
              ),
              _SettingsCard(
                title: context.loc.mempoolSettingsTitle,
                value: _mempoolSettings(context, settings),
              ),
              _SettingsCard(
                title: context.loc.settingsPayjoinTitle,
                value: _payjoinSettings(context, settings.payjoin),
              ),
            ],
            const Gap(16),
            Text(
              context.loc.walletBackupMetadataExcluded,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final String value;

  const _SettingsCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(title: Text(title), subtitle: SelectableText(value)),
  );
}

String _appSettings(BuildContext context, WalletPortableSettings settings) =>
    context.loc.walletBackupMetadataAppSettingsValue(
      settings.bitcoinUnit.code,
      settings.fiatCurrency,
      settings.language?.label ?? context.loc.themeSystem,
      switch (settings.themeMode) {
        AppThemeMode.system => context.loc.themeSystem,
        AppThemeMode.light => context.loc.themeLight,
        AppThemeMode.dark => context.loc.themeDark,
      },
      _onOff(context, settings.hideAmounts),
    );

String _autoswapSettings(
  BuildContext context,
  WalletAutoswapSettings settings,
) => context.loc.walletBackupMetadataAutoswapValue(
  _onOff(context, settings.enabled),
  settings.balanceThresholdSats,
  settings.triggerBalanceSats,
  settings.feeThresholdPercent,
  _onOff(context, settings.alwaysBlock),
  settings.recipientWalletRef ?? context.loc.walletBackupMetadataNotSet,
);

String _electrumSettings(
  BuildContext context,
  WalletPortableSettings settings,
) {
  return settings.electrum
      .map(
        (value) => context.loc.walletBackupMetadataElectrumValue(
          _network(context, value.network.name),
          value.customServers.isEmpty
              ? context.loc.electrumDefaultServers
              : value.customServers.join(', '),
          _onOff(context, value.validateDomain),
          value.stopGap,
          value.timeout,
          value.retry,
        ),
      )
      .join('\n');
}

String _mempoolSettings(BuildContext context, WalletPortableSettings settings) {
  return settings.mempool
      .map(
        (value) => context.loc.walletBackupMetadataMempoolValue(
          _network(context, value.network.name),
          value.customServer ?? context.loc.mempoolSettingsDefaultServer,
          _onOff(context, value.useForFeeEstimation),
        ),
      )
      .join('\n');
}

String _payjoinSettings(BuildContext context, WalletPayjoinSettings settings) =>
    context.loc.walletBackupMetadataPayjoinValue(
      _onOff(context, settings.enabled),
      settings.minimumAmountSats,
      settings.sessionLifetimeSeconds,
    );

String _onOff(BuildContext context, bool value) => value
    ? context.loc.walletBackupMetadataOn
    : context.loc.walletBackupMetadataOff;

String _network(BuildContext context, String name) => switch (name) {
  'bitcoinMainnet' => context.loc.mempoolNetworkBitcoinMainnet,
  'bitcoinTestnet' => context.loc.mempoolNetworkBitcoinTestnet,
  'liquidMainnet' => context.loc.mempoolNetworkLiquidMainnet,
  'liquidTestnet' => context.loc.mempoolNetworkLiquidTestnet,
  _ => throw StateError('Unknown backup settings network'),
};

class _CountCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _CountCard({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(count.toString()),
    ),
  );
}
