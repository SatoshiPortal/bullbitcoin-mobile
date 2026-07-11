import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_config_form.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

// Backend online/offline status dot.
const double _statusDotSize = 10;
// Fixed height of the scrollable notification debug console.
const double _consoleHeight = 240;

class SpSettingsPage extends StatefulWidget {
  const SpSettingsPage({super.key});

  @override
  State<SpSettingsPage> createState() => _SpSettingsPageState();
}

class _SpSettingsPageState extends State<SpSettingsPage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      if (!mounted) return;
      final settingsCubit = context.read<SpSettingsCubit>();
      final network = context.read<SpCubit>().state.network;
      // initFromNetwork surfaces any config-load failure into the cubit state
      // (shown inline); await it so the future is not silently dropped.
      await settingsCubit.initFromNetwork(network);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SpCubit, SpState>(
      listenWhen: (previous, current) => previous.network != current.network,
      listener: (context, state) {
        unawaited(context.read<SpSettingsCubit>().initFromNetwork(state.network));
      },
      child: BlocConsumer<SpSettingsCubit, SpSettingsState>(
        listenWhen: (previous, current) => !previous.saved && current.saved,
        listener: (context, state) {
          unawaited(context.read<SpCubit>().load());
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(context.loc.spSettingsTitle)),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BackendConfigSection(),
                    const Gap(24),
                    const _WalletManagementSection(),
                    const Gap(24),
                    const _NotificationConsoleSection(),
                    if (state.isSaving || state.isFetchingDefaults) ...[
                      const Gap(16),
                      LinearProgressIndicator(
                        backgroundColor: context.appColors.surface,
                        color: context.appColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BackendConfigSection extends StatelessWidget {
  const _BackendConfigSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpSettingsCubit>().state;
    final cubit = context.read<SpSettingsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.spSettingsBackendConfig, style: context.font.titleMedium),
        const Gap(8),
        SpBackendConfigForm<SpSettingsState>(
          state: state,
          cubit: cubit,
          isBusy: state.isSaving,
          header: const _BackendStatusLine(),
          blindbitFieldKey: ValueKey('settings_blindbit_${state.formRevision}'),
          electrumFieldKey: ValueKey('settings_electrum_${state.formRevision}'),
          // Network is fixed once the wallet exists: changing it would be a
          // different wallet. Read-only in settings; only editable at creation.
          networkField: TextFormField(
            key: ValueKey('settings_network_${state.network.name}'),
            initialValue: state.network.name,
            enabled: false,
            decoration: InputDecoration(
              labelText: context.loc.spNetworkLabel,
              helperText: context.loc.spSettingsNetworkHelper,
            ),
          ),
          submit: BBButton.big(
            onPressed: () async {
              final confirmed = await _confirm(
                context,
                title: context.loc.spSaveBackendConfigTitle,
                content: context.loc.spSaveBackendConfigContent,
                confirmLabel: context.loc.save,
              );
              if (!confirmed || !context.mounted) return;
              await cubit.saveBackendConfig();
            },
            label: context.loc.spSaveBackendConfigButton,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
            disabled: !state.canSave,
          ),
        ),
      ],
    );
  }
}

class _WalletManagementSection extends StatelessWidget {
  const _WalletManagementSection();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((SpCubit cubit) => cubit.state.isLoading);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.spWalletManagement, style: context.font.titleMedium),
        const Gap(4),
        SettingsEntryItem(
          icon: Icons.account_balance_wallet,
          title: context.loc.spOpenWallet,
          onTap: () => context.pushNamed(SpRoute.spWalletDetail.name),
        ),
        SettingsEntryItem(
          icon: Icons.toll,
          title: context.loc.coinsTitle,
          onTap: () => context.pushNamed(SpRoute.spCoins.name),
        ),
        SettingsEntryItem(
          icon: Icons.search,
          title: context.loc.spScanNow,
          onTap: () {
            unawaited(context.read<SpCubit>().scan());
            context.pushNamed(SpRoute.spScan.name);
          },
        ),
        SettingsEntryItem(
          icon: Icons.delete_outline,
          title: context.loc.spDeleteWalletEntry,
          iconColor: context.appColors.error,
          textColor: context.appColors.error,
          onTap: isLoading
              ? null
              : () async {
                  final confirmed = await _confirm(
                    context,
                    title: context.loc.spDeleteWalletTitle,
                    content: context.loc.spDeleteWalletContent,
                    confirmLabel: context.loc.delete,
                  );
                  if (!confirmed || !context.mounted) return;
                  await context.read<SpCubit>().revokeWallet();
                  if (!context.mounted) return;
                  context.goNamed(WalletRoute.walletHome.name);
                },
        ),
      ],
    );
  }
}

/// Plain backend reachability line, driven by SpCubit's online/offline state.
class _BackendStatusLine extends StatelessWidget {
  const _BackendStatusLine();

  @override
  Widget build(BuildContext context) {
    final online = context.select((SpCubit c) => c.state.backendOnline);
    final color = online ? context.appColors.success : context.appColors.error;
    return Row(
      children: [
        Icon(
          online ? Icons.circle : Icons.circle_outlined,
          size: _statusDotSize,
          color: color,
        ),
        const Gap(6),
        Text(
          online ? context.loc.spBackendOnline : context.loc.spBackendOffline,
          style: context.font.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Debug console: live list of every notification received from the Rust side.
class _NotificationConsoleSection extends StatelessWidget {
  const _NotificationConsoleSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpSettingsCubit>();
    final console = context.select((SpSettingsCubit c) => c.state.console);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.loc.spNotificationsDebug, style: context.font.titleMedium),
            TextButton(
              onPressed: console.isEmpty ? null : cubit.clearConsole,
              child: Text(context.loc.spClearButton),
            ),
          ],
        ),
        const Gap(8),
        Container(
          height: _consoleHeight,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.border),
          ),
          child: console.isEmpty
              ? Center(
                  child: Text(
                    context.loc.spNoNotifications,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: console.length,
                  itemBuilder: (context, i) {
                    // Newest first.
                    final line = console[console.length - 1 - i];
                    return Text(
                      '${_hms(line.time)}  ${line.text}',
                      style: context.font.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: context.appColors.onSurface,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _hms(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
}) async {
  final result = await BlurredDialog.show<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.loc.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
