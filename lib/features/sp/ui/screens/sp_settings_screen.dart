import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/presentation/sp_notification_console_text.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_state.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_config_form.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Backend online/offline status dot.
const double _statusDotSize = 10;
// Fixed height of the scrollable notification debug console.
const double _consoleHeight = 240;

class SpSettingsScreen extends StatefulWidget {
  const SpSettingsScreen({super.key, required this.exitRedirectPath});

  /// Where deleting the wallet leaves SP for; supplied by the composition root
  /// so this screen never imports another feature's router.
  final String exitRedirectPath;

  @override
  State<SpSettingsScreen> createState() => _SpSettingsScreenState();
}

class _SpSettingsScreenState extends State<SpSettingsScreen> {
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
        unawaited(
          context.read<SpSettingsCubit>().initFromNetwork(state.network),
        );
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
                    _WalletManagementSection(
                      exitRedirectPath: widget.exitRedirectPath,
                    ),
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
    // A save recreates the session, so it must not start while a revoke is
    // tearing that same session down. The two live on this one screen.
    final isRevoking = context.select(
      (SpCubit cubit) => cubit.state.isRevoking,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.spSettingsBackendConfig,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        SpBackendConfigForm<SpSettingsState>(
          state: state,
          isBusy: state.isSaving,
          header: const _BackendStatusLine(),
          onFetchDefaults: cubit.fetchRegtestDefaults,
          onBlindbitChanged: cubit.setBlindbitUrl,
          onTestBlindbit: cubit.testBlindbit,
          onElectrumChanged: cubit.setElectrumUrl,
          onTestElectrum: cubit.testElectrum,
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
            disabled: !state.canSave || isRevoking,
          ),
        ),
      ],
    );
  }
}

class _WalletManagementSection extends StatelessWidget {
  const _WalletManagementSection({required this.exitRedirectPath});

  final String exitRedirectPath;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((SpCubit cubit) => cubit.state.isLoading);
    final isScanning = context.select(
      (SpCubit cubit) => cubit.state.isScanning,
    );
    // A revoke tears down the session a save is recreating, so the delete entry
    // is blocked while a save runs, not only while the SP cubit is busy.
    final isSaving = context.select(
      (SpSettingsCubit cubit) => cubit.state.isSaving,
    );
    final disabled = isLoading || isScanning || isSaving;

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
          title: context.loc.spScan,
          onTap: () => context.pushNamed(SpRoute.spScan.name),
        ),
        SettingsEntryItem(
          icon: Icons.verified_outlined,
          title: context.loc.spHeaderValidationTitle,
          onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
        ),
        SettingsEntryItem(
          icon: Icons.autorenew,
          title: context.loc.spAutoScanEntry,
          subtitle: context.select((SpCubit c) => c.state.isAutoScanEnabled)
              ? context.loc.spAutoScanOnSubtitle
              : context.loc.spAutoScanOffSubtitle,
          trailing: Switch(
            value: context.select((SpCubit c) => c.state.isAutoScanEnabled),
            onChanged: disabled
                ? null
                : (value) => unawaited(
                    context.read<SpCubit>().setAutoScanEnabled(
                      isEnabled: value,
                    ),
                  ),
          ),
        ),
        SettingsEntryItem(
          icon: Icons.restart_alt,
          title: context.loc.spClearScanStateEntry,
          onTap: disabled
              ? null
              : () async {
                  final confirmed = await _confirm(
                    context,
                    title: context.loc.spClearScanStateTitle,
                    content: context.loc.spClearScanStateContent,
                    confirmLabel: context.loc.spClearButton,
                  );
                  if (!confirmed || !context.mounted) return;
                  final ok = await context.read<SpCubit>().clearScanState();
                  if (!context.mounted) return;
                  final message = ok
                      ? context.loc.spClearScanStateSuccess
                      : context.read<SpCubit>().state.error?.toTranslated(
                              context,
                            ) ??
                            context.loc.oopsSomethingWentWrong;
                  SnackBarUtils.showSnackBar(context, message);
                },
        ),
        SettingsEntryItem(
          icon: Icons.delete_outline,
          title: context.loc.spDeleteWalletEntry,
          iconColor: context.appColors.error,
          textColor: context.appColors.error,
          onTap: disabled
              ? null
              : () async {
                  final confirmed = await _confirm(
                    context,
                    title: context.loc.spDeleteWalletTitle,
                    content: context.loc.spDeleteWalletContent,
                    confirmLabel: context.loc.delete,
                  );
                  if (!confirmed || !context.mounted) return;
                  final deleted = await context.read<SpCubit>().revokeWallet();
                  if (!context.mounted) return;
                  if (!deleted) {
                    final message =
                        context.read<SpCubit>().state.error?.toTranslated(
                          context,
                        ) ??
                        context.loc.oopsSomethingWentWrong;
                    SnackBarUtils.showSnackBar(context, message);
                    return;
                  }
                  context.go(exitRedirectPath);
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
            Text(
              context.loc.spNotificationsDebug,
              style: context.font.titleMedium,
            ),
            BBButton.small(
              compact: true,
              label: context.loc.spClearButton,
              onPressed: cubit.clearConsole,
              disabled: console.isEmpty,
              bgColor: context.appColors.transparent,
              textColor: context.appColors.secondary,
              textStyle: context.font.labelMedium,
              outlined: true,
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
                      '${DateFormat.Hms().format(line.time)}  ${line.notification.consoleText}',
                      // No monospace token in the theme yet; the family is the
                      // one thing this console still hardcodes.
                      style: context.font.labelMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: context.appColors.onSurface,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
        Row(
          children: [
            Expanded(
              child: BBButton.small(
                label: context.loc.cancel,
                onPressed: () => Navigator.of(context).pop(false),
                bgColor: context.appColors.transparent,
                textColor: context.appColors.secondary,
                textStyle: context.font.headlineLarge,
                outlined: true,
              ),
            ),
            const Gap(12),
            Expanded(
              child: BBButton.small(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
                textStyle: context.font.headlineLarge,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
