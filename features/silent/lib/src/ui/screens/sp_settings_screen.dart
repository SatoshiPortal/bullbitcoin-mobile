import 'dart:async';

import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullButtonSize,
        BullConfirmDialog,
        BullSettingsEntryItem,
        BullShapesX,
        BullSnackBar,
        BullThemeX,
        BullTypographyX,
        Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/presentation/sp_failure_l10n.dart';
import 'package:silent/src/presentation/sp_notification_console_text.dart';
import 'package:silent/src/presentation/sp_settings_cubit.dart';
import 'package:silent/src/presentation/sp_settings_state.dart';
import 'package:silent/src/presentation/sp_state.dart';
import 'package:silent/src/ui/sp_router.dart';
import 'package:silent/src/ui/widgets/sp_backend_config_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          unawaited(context.read<SpCubit>().reloadAfterBackendChange());
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(context.silentLoc.silentSettingsTitle)),
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
                        backgroundColor: context.bull.surface,
                        color: context.bull.primary,
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
          context.silentLoc.silentSettingsBackendConfig,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        SpBackendConfigForm<SpSettingsState>(
          state: state,
          isBusy: state.isSaving,
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
              labelText: context.silentLoc.silentNetworkLabel,
              helperText: context.silentLoc.silentSettingsNetworkHelper,
            ),
          ),
          submit: BullButton.primary(
            onPressed: (!state.canSave || isRevoking)
                ? null
                : () async {
                    final confirmed = await _confirm(
                      context,
                      title: context.silentLoc.silentSaveBackendConfigTitle,
                      content: context.silentLoc.silentSaveBackendConfigContent,
                      confirmLabel: context.silentLoc.save,
                    );
                    if (!confirmed || !context.mounted) return;
                    await cubit.saveBackendConfig();
                  },
            label: context.silentLoc.silentSaveBackendConfigButton,
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
        Text(
          context.silentLoc.silentWalletManagement,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(4),
        BullSettingsEntryItem(
          icon: Icons.account_balance_wallet,
          title: context.silentLoc.silentOpenWallet,
          onTap: () => context.pushNamed(SpRoute.spWalletDetail.name),
        ),
        BullSettingsEntryItem(
          icon: Icons.toll,
          title: context.silentLoc.coinsTitle,
          onTap: () => context.pushNamed(SpRoute.spCoins.name),
        ),
        BullSettingsEntryItem(
          icon: Icons.search,
          title: context.silentLoc.silentScan,
          onTap: () => context.pushNamed(SpRoute.spScan.name),
        ),
        BullSettingsEntryItem(
          icon: Icons.verified_outlined,
          title: context.silentLoc.silentHeaderValidationTitle,
          onTap: () => context.pushNamed(SpRoute.spHeaderValidation.name),
        ),
        BullSettingsEntryItem(
          icon: Icons.autorenew,
          title: context.silentLoc.silentAutoScanEntry,
          subtitle: context.select((SpCubit c) => c.state.isAutoScanEnabled)
              ? context.silentLoc.silentAutoScanOnSubtitle
              : context.silentLoc.silentAutoScanOffSubtitle,
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
        BullSettingsEntryItem(
          icon: Icons.restart_alt,
          title: context.silentLoc.silentClearScanStateEntry,
          onTap: disabled
              ? null
              : () async {
                  final confirmed = await _confirm(
                    context,
                    title: context.silentLoc.silentClearScanStateTitle,
                    content: context.silentLoc.silentClearScanStateContent,
                    confirmLabel: context.silentLoc.silentClearButton,
                  );
                  if (!confirmed || !context.mounted) return;
                  final ok = await context.read<SpCubit>().clearScanState();
                  if (!context.mounted) return;
                  final message = ok
                      ? context.silentLoc.silentClearScanStateSuccess
                      : context.read<SpCubit>().state.error?.toTranslated(
                              context,
                            ) ??
                            context.silentLoc.oopsSomethingWentWrong;
                  BullSnackBar.show(context, message: message);
                },
        ),
        BullSettingsEntryItem(
          icon: Icons.delete_outline,
          title: context.silentLoc.silentDeleteWalletEntry,
          iconColor: context.bull.error,
          textColor: context.bull.error,
          onTap: disabled
              ? null
              : () async {
                  final confirmed = await _confirm(
                    context,
                    title: context.silentLoc.silentDeleteWalletTitle,
                    content: context.silentLoc.silentDeleteWalletContent,
                    confirmLabel: context.silentLoc.delete,
                    destructive: true,
                  );
                  if (!confirmed || !context.mounted) return;
                  final deleted = await context.read<SpCubit>().revokeWallet();
                  if (!context.mounted) return;
                  if (!deleted) {
                    final message =
                        context.read<SpCubit>().state.error?.toTranslated(
                          context,
                        ) ??
                        context.silentLoc.oopsSomethingWentWrong;
                    BullSnackBar.show(context, message: message);
                    return;
                  }
                  context.go(exitRedirectPath);
                },
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
              context.silentLoc.silentNotificationsDebug,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            BullButton.secondary(
              size: BullButtonSize.small,
              compact: true,
              label: context.silentLoc.silentClearButton,
              onPressed: (console.isEmpty) ? null : cubit.clearConsole,
              textStyle: context.bullType.caption,
            ),
          ],
        ),
        const Gap(8),
        Container(
          height: _consoleHeight,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.bull.surface,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
            border: Border.all(color: context.bull.border),
          ),
          child: console.isEmpty
              ? Center(
                  child: Text(
                    context.silentLoc.silentNoNotifications,
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.bull.textMuted),
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
                      style: context.bullType.caption.copyWith(
                        fontFamily: 'monospace',
                        color: context.bull.onSurface,
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
  bool destructive = false,
}) => BullConfirmDialog.show(
  context,
  title: title,
  message: content,
  confirmLabel: confirmLabel,
  cancelLabel: context.silentLoc.cancel,
  destructive: destructive,
);
