import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet_sync/domain/wallet_sync_selection.dart';
import 'package:bb_mobile/features/wallet_sync/domain/bitcoin_recovery_estimate.dart';
import 'package:bb_mobile/features/wallet_sync/ui/widgets/bitcoin_sync_source_cards.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Form state is local to this sheet. No wallet is created or discovered here.
class WalletSyncOptionsSheet extends StatefulWidget {
  final BitcoinNetwork network;
  final bool askScriptType;
  final WalletSyncSelection initial;
  final bool changingSource;

  const WalletSyncOptionsSheet({
    super.key,
    required this.network,
    this.askScriptType = false,
    this.initial = const WalletSyncSelection(),
    this.changingSource = false,
  });

  @override
  State<WalletSyncOptionsSheet> createState() => _WalletSyncOptionsSheetState();
}

class _WalletSyncOptionsSheetState extends State<WalletSyncOptionsSheet> {
  late BitcoinSyncSource _source = widget.initial.source;
  late ScriptType _script = widget.initial.scriptType;
  int _step = 0;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(BullSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            BullTopBar(
              title: '',
              titleWidget: Semantics(
                header: true,
                child: BullText(
                  switch (_step) {
                    0 => context.loc.syncSourceTitle,
                    1 => context.loc.importMnemonicSelectScriptType,
                    _ => context.loc.syncBirthdayTitle,
                  },
                  style: context.bullText.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              backLabel: context.loc.syncBack,
              onBack: _step == 0
                  ? null
                  : () => setState(() {
                      _step = _step == 1
                          ? 0
                          : widget.askScriptType
                          ? 1
                          : 0;
                    }),
            ),
            const Gap(BullSpacing.lg),
            if (_step == 0) ...[
              BitcoinSyncSourceCards(
                value: _source,
                onChanged: (source) => setState(() => _source = source),
              ),
              const Gap(BullSpacing.lg),
              _FormButton(
                label: context.loc.importMnemonicContinue,
                onPressed: () async {
                  if (widget.changingSource &&
                      _source == widget.initial.source) {
                    Navigator.of(context).pop(widget.initial);
                    return;
                  }
                  if (_source == BitcoinSyncSource.electrum) {
                    if (widget.changingSource &&
                        widget.initial.source != _source) {
                      final confirmed = await confirmSyncWarning(
                        context,
                        context.loc.syncSwitchToServerWarning,
                      );
                      if (!confirmed || !context.mounted) return;
                    }
                    Navigator.of(context).pop(
                      WalletSyncSelection(
                        source: _source,
                        birthday: widget.initial.birthday,
                        scriptType: _script,
                        scanScriptType: widget.initial.scanScriptType,
                      ),
                    );
                  } else {
                    setState(() => _step = widget.askScriptType ? 1 : 2);
                  }
                },
              ),
            ] else if (_step == 1) ...[
              BullText(
                context.loc.syncScriptHelp,
                style: context.bullText.bodyMedium,
              ),
              const Gap(BullSpacing.md),
              BullSelectableList(
                selectedValue: _script.name,
                onChanged: (value) =>
                    setState(() => _script = ScriptType.values.byName(value)),
                items: [
                  BullSelectableListItem(
                    title: context.loc.syncNativeSegwit,
                    subtitle1: 'bc1q…',
                    subtitle2: '',
                    value: ScriptType.bip84.name,
                  ),
                  BullSelectableListItem(
                    title: context.loc.syncNestedSegwit,
                    subtitle1: '3…',
                    subtitle2: '',
                    value: ScriptType.bip49.name,
                  ),
                  BullSelectableListItem(
                    title: context.loc.importMnemonicLegacy,
                    subtitle1: '1…',
                    subtitle2: '',
                    value: ScriptType.bip44.name,
                  ),
                ],
              ),
              _FormButton(
                label: context.loc.importMnemonicContinue,
                onPressed: () => setState(() => _step = 2),
              ),
            ] else ...[
              if (widget.changingSource &&
                  widget.initial.source == BitcoinSyncSource.electrum) ...[
                BullText(
                  context.loc.syncSwitchToPrivateWarning,
                  style: context.bullText.bodyMedium,
                ),
                const Gap(BullSpacing.md),
              ],
              WalletBirthdayForm(
                network: widget.network,
                scriptType:
                    widget.initial.scanScriptType ??
                    BitcoinSyncScriptType.fromScriptType(_script),
                showTitle: false,
                initialBirthday: widget.initial.birthday?.dateTime,
                onConfirmed: (birthday) => Navigator.of(context).pop(
                  WalletSyncSelection(
                    source: _source,
                    birthday: birthday,
                    scriptType: _script,
                    scanScriptType: widget.initial.scanScriptType,
                  ),
                ),
              ),
            ],
            _FormButton(
              secondary: true,
              label: context.loc.cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmSyncWarning(BuildContext context, String warning) async =>
    await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullText(warning, style: context.bullText.bodyMedium),
          const Gap(BullSpacing.lg),
          _FormButton(
            label: context.loc.importMnemonicContinue,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
          _FormButton(
            secondary: true,
            label: context.loc.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ],
      ),
    ) ??
    false;

class WalletBirthdayForm extends StatefulWidget {
  final BitcoinNetwork network;
  final BitcoinSyncScriptType scriptType;
  final DateTime? initialBirthday;
  final DateTime? latest;
  final DateTime? now;
  final bool showTitle;
  final ValueChanged<WalletBirthday?> onConfirmed;

  const WalletBirthdayForm({
    super.key,
    required this.network,
    this.scriptType = BitcoinSyncScriptType.segwitV0,
    this.initialBirthday,
    this.latest,
    this.now,
    this.showTitle = true,
    required this.onConfirmed,
  });

  @override
  State<WalletBirthdayForm> createState() => _WalletBirthdayFormState();
}

class _WalletBirthdayFormState extends State<WalletBirthdayForm> {
  late final DateTime _now = (widget.now ?? DateTime.now()).toUtc();
  late DateTime? _month = switch (widget.initialBirthday) {
    final birthday? => DateTime.utc(birthday.year, birthday.month),
    null => null,
  };

  Future<void> _chooseUnknown() async {
    final scriptType = widget.scriptType;
    final floor = widget.network.isMainnet
        ? scriptType.floor
        : BitcoinSyncCheckpoint.genesis(widget.network);
    final start = BitcoinRecoveryEstimate.startDate(
      network: widget.network,
      scriptType: scriptType,
      checkpoint: floor,
    );
    final date = start == null
        ? ''
        : DateFormat.yMMMM(context.loc.localeName).format(start);
    final estimate = BitcoinRecoveryEstimate(scriptType);
    final accepted = await BullDialog.show<bool>(
      context: context,
      builder: (dialogContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BullText(
              widget.network.isMainnet
                  ? scriptType == BitcoinSyncScriptType.preSegwit
                        ? context.loc.syncUnknownHdStart(date)
                        : context.loc.syncUnknownScriptStart(date)
                  : context.loc.syncUnknownTestnetStart,
              style: context.bullText.bodyMedium,
            ),
            const Gap(BullSpacing.md),
            if (start != null)
              BullText(
                context.loc.syncMonthsToCheck(
                  BitcoinRecoveryEstimate.monthsFrom(start, _now),
                ),
                style: context.bullText.bodyMedium,
              ),
            if (widget.network.isMainnet) ...[
              const Gap(BullSpacing.md),
              BullText(
                scriptType == BitcoinSyncScriptType.segwitV0
                    ? context.loc.syncUnknownSegwitCost
                    : context.loc.syncUnknownEstimatedCost(
                        estimate.minutes,
                        estimate.gigabytes,
                      ),
                style: context.bullText.bodyMedium,
              ),
            ],
            const Gap(BullSpacing.md),
            BullText(
              context.loc.syncRecoveryPreparation,
              style: context.bullText.bodyMedium,
            ),
            const Gap(BullSpacing.lg),
            _FormButton(
              label: context.loc.syncScanFromDate(date),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            _FormButton(
              secondary: true,
              label: context.loc.syncPickDate,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      widget.onConfirmed(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.loc.localeName;
    final earliest = DateTime.utc(2009, 1);
    final limit = widget.latest;
    final maximum = limit != null && limit.isBefore(_now) ? limit : _now;
    final month = _month;
    final selectedMonth = month == null
        ? null
        : month.isAfter(maximum)
        ? DateTime.utc(maximum.year, maximum.month)
        : month;
    final birthday = selectedMonth == null
        ? null
        : WalletBirthday.tryCreate(selectedMonth, now: _now);
    final checkpoint = birthday == null
        ? null
        : const ResolveBitcoinSyncCheckpointUsecase().execute(
            network: widget.network,
            birthday: birthday.dateTime,
            scriptType: widget.scriptType,
            now: _now,
          );
    final resolved = switch (checkpoint) {
      Ok(:final value) => value,
      _ => null,
    };
    final start = resolved == null
        ? null
        : BitcoinRecoveryEstimate.startDate(
            network: widget.network,
            scriptType: widget.scriptType,
            checkpoint: resolved,
          );
    final months = start == null
        ? null
        : BitcoinRecoveryEstimate.monthsFrom(start, _now);
    final clamped =
        widget.network.isMainnet &&
        selectedMonth != null &&
        selectedMonth.isBefore(
          DateTime.utc(
            widget.scriptType.earliestDate.year,
            widget.scriptType.earliestDate.month,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Semantics(
            header: true,
            child: BullText(
              context.loc.syncBirthdayTitle,
              style: context.bullText.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(BullSpacing.md),
        ],
        BullText(
          context.loc.syncBirthdayHelp,
          style: context.bullText.bodyMedium,
        ),
        const Gap(BullSpacing.lg),
        BullMonthPicker(
          value: selectedMonth,
          now: _now,
          earliest: earliest,
          latest: widget.latest,
          monthLabel: context.loc.syncMonth,
          yearLabel: context.loc.syncYear,
          monthName: (date) => DateFormat.MMMM(locale).format(date),
          onChanged: (month) => setState(() {
            _month = month;
          }),
        ),
        if (clamped) ...[
          const Gap(BullSpacing.md),
          BullText(
            context.loc.syncBirthdayClamped(
              DateFormat.yMMMM(locale).format(widget.scriptType.earliestDate),
            ),
            style: context.bullText.bodyMedium,
          ),
        ],
        if (checkpoint case Ok(
          value: BitcoinSyncCheckpoint(timestamp: final date?),
        )) ...[
          const Gap(BullSpacing.md),
          BullText(
            context.loc.syncScanningFrom(
              DateFormat.yMMMMd(locale).format(date),
            ),
            style: context.bullText.bodyMedium,
          ),
        ],
        if (widget.latest == null)
          Center(
            child: BullButton.small(
              compact: true,
              height: 44,
              label: context.loc.syncUnknown,
              onPressed: _chooseUnknown,
              bgColor: context.bull.transparent,
              textColor: context.bull.primary,
              textStyle: context.bullText.bodyMedium,
            ),
          ),
        const Gap(BullSpacing.md),
        if (months != null) ...[
          BullText(
            context.loc.syncMonthsToCheck(months),
            style: context.bullText.bodyMedium,
          ),
          const Gap(BullSpacing.md),
        ],
        _FormButton(
          label: widget.latest != null && selectedMonth != null
              ? context.loc.syncUseMonth(
                  DateFormat.yMMMM(locale).format(selectedMonth),
                )
              : context.loc.importMnemonicContinue,
          disabled: checkpoint is Err || birthday == null,
          onPressed: () {
            if (birthday != null) widget.onConfirmed(birthday);
          },
        ),
      ],
    );
  }
}

class _FormButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool secondary;
  final bool disabled;

  const _FormButton({
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BullSpacing.xs),
    child: BullButton.big(
      label: label,
      onPressed: onPressed,
      disabled: disabled,
      outlined: secondary,
      bgColor: secondary ? context.bull.surface : context.bull.primary,
      textColor: secondary ? context.bull.primary : context.bull.onPrimary,
    ),
  );
}
