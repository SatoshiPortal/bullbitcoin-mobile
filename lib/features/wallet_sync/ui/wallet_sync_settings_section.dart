import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/load_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/usecases/save_wallet_sync_settings_usecase.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:bb_mobile/features/wallet_sync/presentation/wallet_sync_settings_cubit.dart';
import 'package:bb_mobile/features/wallet_sync/presentation/wallet_sync_options_failure_l10n.dart';
import 'package:bb_mobile/features/wallet_sync/ui/wallet_sync_options_sheet.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../domain/bitcoin_recovery_estimate.dart';
import 'package:primitives/primitives.dart';

typedef ChooseWalletSync =
    Future<WalletSyncSelection?> Function(
      BuildContext context, {
      BitcoinNetwork? network,
      bool askScriptType,
      WalletSyncSelection initial,
      bool changingSource,
    });

class WalletSyncSettingsSection extends StatelessWidget {
  final String walletId;
  final LoadWalletSyncSettingsUsecase load;
  final SaveWalletSyncSettingsUsecase save;
  final ChooseWalletSync choose;
  final Widget? networkPreferences;

  const WalletSyncSettingsSection({
    super.key,
    required this.walletId,
    required this.load,
    required this.save,
    required this.choose,
    this.networkPreferences,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: _WalletSyncSettingsKey(walletId),
    create: (_) =>
        WalletSyncSettingsCubit(walletId: walletId, load: load, save: save)
          ..load(),
    child: BlocBuilder<WalletSyncSettingsCubit, WalletSyncSettingsState>(
      builder: (context, state) {
        if (state is WalletSyncSettingsLoading) return const SizedBox.shrink();
        if (state is WalletSyncSettingsUnavailable) {
          return BullText(
            state.failure.toTranslated(context),
            style: context.bullText.bodyMedium,
          );
        }
        if (state is! WalletSyncSettingsReady) return const SizedBox.shrink();
        final settings = state.settings;
        final cubit = context.read<WalletSyncSettingsCubit>();
        if (settings.isLiquid) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SyncSectionHeading(context.loc.syncSectionTitle),
              const Gap(BullSpacing.md),
              _SyncInfoField(
                label: context.loc.syncMethod,
                value: context.loc.syncServerOnly,
              ),
            ],
          );
        }
        final storedBirthday = settings.birthday;
        final now = DateTime.now().toUtc();
        final birthday = storedBirthday != null && storedBirthday.isAfter(now)
            ? now
            : storedBirthday;
        final checkpoint = const ResolveBitcoinSyncCheckpointUsecase().execute(
          network: settings.network,
          birthday: birthday,
          now: now,
          scriptType: settings.scanScriptType,
        );
        final start = switch (checkpoint) {
          Ok(:final value) => BitcoinRecoveryEstimate.startDate(
            network: settings.network,
            scriptType: settings.scanScriptType,
            checkpoint: value,
          ),
          Err() => null,
        };
        final floor = settings.network.isMainnet
            ? settings.scanScriptType.floor
            : BitcoinSyncCheckpoint.genesis(settings.network);
        final canScanEarlier = switch (checkpoint) {
          Ok(:final value) => value.height > floor.height,
          Err() => false,
        };
        final floorDate = settings.network.isMainnet
            ? settings.scanScriptType.earliestDate
            : start;
        final birthdayMonth =
            birthday == null ||
                floorDate != null && birthday.isBefore(floorDate)
            ? floorDate ?? start ?? now
            : birthday;
        final locale = context.loc.localeName;
        final history = DateFormat.yMMMM(locale).format(birthdayMonth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SyncSectionHeading(context.loc.syncSectionTitle),
            const Gap(BullSpacing.md),
            if ((settings.source, networkPreferences) case (
              BitcoinSyncSource.compactBlockFilters,
              final preferences?,
            )) ...[
              preferences,
              const Gap(BullSpacing.md),
            ],
            _SyncInfoField(
              label: context.loc.syncMethod,
              editable: true,
              value: settings.source == BitcoinSyncSource.electrum
                  ? context.loc.syncFastTitle
                  : context.loc.syncPrivateTitle,
              onTap: state.saving
                  ? null
                  : () async {
                      final selection = await choose(
                        context,
                        network: settings.network,
                        changingSource: true,
                        initial: WalletSyncSelection(
                          source: settings.source,
                          scanScriptType: settings.scanScriptType,
                          birthday: birthday == null
                              ? null
                              : WalletBirthday.tryCreate(birthday),
                        ),
                      );
                      if (selection == null ||
                          cubit.isClosed ||
                          selection.source == settings.source) {
                        return;
                      }
                      await cubit.save(selection);
                    },
            ),
            const Gap(BullSpacing.md),
            _SyncInfoField(
              label: context.loc.syncHistoryStarts,
              value: birthday == null
                  ? context.loc.syncUnknownDate(history)
                  : history,
            ),
            Row(
              children: [
                Flexible(
                  child: BullButton.small(
                    compact: true,
                    height: 44,
                    textStyle: context.bullText.bodyMedium,
                    label: context.loc.syncEarlierDate,
                    bgColor: context.bull.transparent,
                    textColor: context.bull.primary,
                    disabled: state.saving || !canScanEarlier,
                    onPressed: () async {
                      final selected =
                          await BullBottomSheet.show<WalletBirthday>(
                            context: context,
                            child: SafeArea(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(BullSpacing.lg),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Semantics(
                                        header: true,
                                        child: BullText(
                                          context.loc.syncEarlierDate,
                                          style:
                                              context.bullText.headlineMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const Gap(BullSpacing.lg),
                                      BullText(
                                        context.loc.syncRescanHelp,
                                        style: context.bullText.bodyMedium,
                                      ),
                                      const Gap(BullSpacing.lg),
                                      WalletBirthdayForm(
                                        showTitle: false,
                                        network: settings.network,
                                        scriptType: settings.scanScriptType,
                                        initialBirthday: birthdayMonth,
                                        latest: DateTime.utc(
                                          birthdayMonth.year,
                                          birthdayMonth.month - 1,
                                        ),
                                        onConfirmed: (value) {
                                          if (value != null) {
                                            Navigator.of(context).pop(value);
                                          }
                                        },
                                      ),
                                      BullButton.big(
                                        label: context.loc.cancel,
                                        bgColor: context.bull.surface,
                                        textColor: context.bull.primary,
                                        outlined: true,
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                      if (selected == null || cubit.isClosed) return;
                      await cubit.save(
                        WalletSyncSelection(
                          source: settings.source,
                          scanScriptType: settings.scanScriptType,
                          birthday: selected,
                        ),
                        earlierOnly: true,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (!canScanEarlier)
              BullText(
                switch (checkpoint) {
                  Err() => context.loc.oopsSomethingWentWrong,
                  Ok() =>
                    settings.network.isMainnet
                        ? context.loc.syncEarlierDateAtFloor
                        : context.loc.syncEarlierDateAtGenesis,
                },
                style: context.bullText.bodyMedium,
                color: context.bull.textMuted,
              ),
            if (state.failure case final failure?)
              BullText(
                failure.toTranslated(context),
                style: context.bullText.bodyMedium,
              ),
          ],
        );
      },
    ),
  );
}

class _WalletSyncSettingsKey extends ValueKey<String> {
  const _WalletSyncSettingsKey(super.value);

  @override
  String toString() => 'WalletSyncSettingsKey';
}

class _SyncSectionHeading extends StatelessWidget {
  final String text;

  const _SyncSectionHeading(this.text);

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: BullText(
      text,
      style: context.bullText.titleSmall,
      color: context.bull.secondary,
    ),
  );
}

class _SyncInfoField extends StatelessWidget {
  final String label;
  final String value;
  final bool editable;
  final VoidCallback? onTap;

  const _SyncInfoField({
    required this.label,
    required this.value,
    this.editable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullText(
          label,
          style: context.bullText.bodyLarge,
          color: context.bull.textMuted,
        ),
        const Gap(BullSpacing.xxs),
        Row(
          children: [
            Expanded(
              child: BullText(
                value,
                style: context.bullText.bodyMedium,
                color: context.bull.onSurface,
              ),
            ),
            if (editable) ...[
              const Gap(BullSpacing.xs),
              BullIcon(BullIcons.chevronRight, color: context.bull.onSurface),
            ],
          ],
        ),
      ],
    );
    if (!editable) return content;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: content,
        ),
      ),
    );
  }
}
