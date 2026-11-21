import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/presentation/scan_start_ticks.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_blindbit_behind_card.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButtonSize, BullButton, BullInputText, Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class SpScanScreen extends StatelessWidget {
  const SpScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          context.loc.spScan,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<SpCubit, SpState>(
          builder: (context, state) {
            if (state.isScanning) return _ScanningView(state: state);
            if (state.error case final error?) {
              return _ErrorView(
                message: error.toTranslated(context),
                retry: state.minBirthdayHeight == null
                    ? context.read<SpCubit>().load
                    : context.read<SpCubit>().retryScan,
              );
            }
            // Caught up states both facts in its own message, so it needs no
            // strip above it. The other views say nothing about whether
            // scanning continues on its own, so they do. A server behind the
            // chain means the wallet is not synced, whatever the cursor says.
            if (state.isCaughtUp) {
              return _CaughtUpView(
                lastDurationSecs: state.scanLastDurationSecs,
                isAutoScanEnabled: state.isAutoScanEnabled,
              );
            }
            return Column(
              children: [
                _AutoScanStatus(isEnabled: state.isAutoScanEnabled),
                if (state.isBlindbitBehind)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SpBlindbitBehindCard(
                      blocksBehind: state.blindbitLag!.blocksBehind,
                    ),
                  ),
                Expanded(
                  child: state.hasPendingScan || state.hasScannedBefore
                      ? _ScanCheckpointView(state: state)
                      : _FirstScanView(state: state),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(child: _ScanProgressCard(state: state)),
        ),
        if (state.error case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toTranslated(context),
              style: context.bullType.body.copyWith(
                color: context.appColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        _BottomAction(
          label: context.loc.spScanStopButton,
          onPressed: () => unawaited(context.read<SpCubit>().stopScan()),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: context.appColors.error, size: 72),
                const Gap(24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    message,
                    style: context.bullType.body.copyWith(
                      color: context.appColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomAction(label: context.loc.retry, onPressed: retry),
      ],
    );
  }
}

class _CaughtUpView extends StatelessWidget {
  const _CaughtUpView({required this.isAutoScanEnabled, this.lastDurationSecs});
  final int? lastDurationSecs;

  /// With automatic scanning off the wallet is caught up right now but will not
  /// stay that way on its own, so the screen must not claim it will.
  final bool isAutoScanEnabled;

  @override
  Widget build(BuildContext context) {
    final duration = lastDurationSecs;
    // No scan button here: the wallet is caught up, so the sync tick keeps it
    // that way without a tap.
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: context.appColors.success,
                  size: 72,
                ),
                const Gap(24),
                Text(
                  isAutoScanEnabled
                      ? context.loc.spScanSyncedAutoOn
                      : context.loc.spScanSyncedManual,
                  style: context.bullType.body
                      .copyWith(fontWeight: FontWeight.w500)
                      .copyWith(color: context.appColors.success),
                ),
                if (duration != null) ...[
                  const Gap(8),
                  Text(
                    context.loc.spScanScannedIn(
                      formatDuration(context.loc, duration),
                    ),
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.appColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Nothing resumes on its own with the toggle off, so the user needs a
        // way to pick the wallet back up as new blocks arrive.
        if (!isAutoScanEnabled)
          _BottomAction(
            label: context.loc.spScanStartButton,
            onPressed: () => context.read<SpCubit>().scan(),
          ),
      ],
    );
  }
}

class _ScanCheckpointView extends StatelessWidget {
  const _ScanCheckpointView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastScannedHeight;
    final tip = state.chainTip;
    final isUnfinished = state.hasPendingScan;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, color: context.appColors.primary, size: 72),
                const Gap(24),
                Text(
                  isUnfinished || last == null
                      ? context.loc.spScanResumeInterrupted
                      : context.loc.spScanScannedThrough('$last'),
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                if (!isUnfinished && !state.isChainTipReliable)
                  Text(
                    context.loc.spWalletScanUnknown,
                    style: context.bullType.label.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  )
                else if (!isUnfinished &&
                    last != null &&
                    tip != null &&
                    tip > last)
                  Text(
                    context.loc.spScanBlocksBehind(tip - last),
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.appColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                if (state.scanLastDurationSecs != null) ...[
                  const Gap(8),
                  Text(
                    context.loc.spScanScannedIn(
                      formatDuration(context.loc, state.scanLastDurationSecs!),
                    ),
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.appColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        _BottomAction(
          label: isUnfinished
              ? context.loc.spScanResumeButton
              : context.loc.spScanCheckForPayments,
          onPressed: () => context.read<SpCubit>().scan(),
        ),
      ],
    );
  }
}

class _FirstScanView extends StatefulWidget {
  const _FirstScanView({required this.state});
  final SpState state;

  @override
  State<_FirstScanView> createState() => _FirstScanViewState();
}

class _FirstScanViewState extends State<_FirstScanView> {
  late Future<Result<int, SpFailure>> _serverTip = _fetchServerTip();

  Future<Result<int, SpFailure>> _fetchServerTip() =>
      context.read<SpCubit>().scanServerTip();

  @override
  Widget build(BuildContext context) {
    final min = widget.state.minBirthdayHeight;
    if (min == null) return const Center(child: CircularProgressIndicator());
    final chainTip = widget.state.chainTip;
    final knownTip = chainTip != null && chainTip >= min ? chainTip : null;
    return FutureBuilder<Result<int, SpFailure>>(
      future: knownTip == null ? _serverTip : null,
      builder: (context, snapshot) {
        final tip =
            knownTip ??
            switch (snapshot.data) {
              Ok(:final value) when value >= min => value,
              _ => null,
            };
        if (tip != null) {
          return _ScanStartChooser(
            minBirthday: min,
            tip: tip,
            onStart: (h) => context.read<SpCubit>().scan(startHeight: h),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spScanWaitingForTip,
                style: context.bullType.body,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return _ErrorView(
          message: context.loc.spScanTipUnavailable,
          retry: () {
            final retry = _fetchServerTip();
            setState(() {
              _serverTip = retry;
            });
          },
        );
      },
    );
  }
}

/// Pick the block height the first scan begins at, via a slider, labelled
/// ruler stops, or a numeric field, kept in sync and clamped to
/// `[minBirthday, tip]`.
class _ScanStartChooser extends StatefulWidget {
  const _ScanStartChooser({
    required this.minBirthday,
    required this.tip,
    required this.onStart,
  });

  final int minBirthday;
  final int tip;
  final void Function(int height) onStart;

  @override
  State<_ScanStartChooser> createState() => _ScanStartChooserState();
}

class _ScanStartChooserState extends State<_ScanStartChooser> {
  late int _height = widget.minBirthday;
  late final TextEditingController _controller = TextEditingController(
    text: '$_height',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clamp(int h) => h.clamp(widget.minBirthday, widget.tip);

  void _setHeight(int h, {bool syncField = true}) {
    final clamped = _clamp(h);
    setState(() => _height = clamped);
    if (syncField) _controller.text = '$clamped';
  }

  @override
  Widget build(BuildContext context) {
    final ticks = scanStartTicks(
      loc: context.loc,
      tip: widget.tip,
      minBirthday: widget.minBirthday,
      blocksPerDay: SpConfig.blocksPerDay,
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.loc.spScanChooseStartMessage,
                  style: context.bullType.body,
                ),
                const Gap(24),
                Slider(
                  value: _height.toDouble().clamp(
                    widget.minBirthday.toDouble(),
                    widget.tip.toDouble(),
                  ),
                  min: widget.minBirthday.toDouble(),
                  max: widget.tip.toDouble(),
                  activeColor: context.appColors.secondary,
                  inactiveColor: context.appColors.surfaceContainer,
                  onChanged: widget.minBirthday == widget.tip
                      ? null
                      : (v) => _setHeight(v.round()),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in ticks)
                      BullButton.secondary(
                        size: BullButtonSize.small,
                        compact: true,
                        label: t.label,
                        onPressed: () => _setHeight(t.height),
                        textStyle: context.bullType.caption,
                      ),
                  ],
                ),
                const Gap(24),
                Text(
                  context.loc.spScanBlockHeightLabel,
                  style: context.bullType.body,
                ),
                const Gap(8),
                Semantics(
                  label: context.loc.spScanBlockHeightLabel,
                  child: BullInputText(
                    controller: _controller,
                    value: _controller.text,
                    digitsOnly: true,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) _setHeight(parsed, syncField: false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStartFromButton('${_clamp(_height)}'),
          onPressed: () => widget.onStart(_clamp(_height)),
        ),
      ],
    );
  }
}

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.scanProgress;
    final current = state.scanCurrent ?? state.scanFrom;
    final target = state.scanTo;
    final phase = state.scanPhase;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phase != null) ...[
          Text(
            context.loc.spScanStep(
              phase == SpScanPhase.spend ? 2 : 1,
              2,
              _phaseLabel(context, phase),
            ),
            style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const Gap(12),
        ],
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  // Indeterminate until the first progress tick, then fill.
                  value: progress > 0 ? progress : null,
                  strokeWidth: 6,
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              ),
              Text(
                context.loc.spScanPercent('${(progress * 100).round()}'),
                style: context.bullType.body.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
        Text(
          current != null && target != null
              ? context.loc.spScanProgressCount('$current', '$target')
              : context.loc.spScanScanning,
          style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const Gap(4),
        Text(
          context.loc.spScanBlocksLabel,
          style: context.bullType.label
              .copyWith(fontWeight: FontWeight.w400)
              .copyWith(color: context.appColors.textMuted),
        ),
        const Gap(8),
        _ScanTimings(
          startTime: state.scanStartTime,
          etaSecs: state.scanEtaSecs,
        ),
      ],
    );
  }
}

/// Live elapsed timer (ticks every second) plus the ETA, shown under the scan
/// progress. A local timer keeps the elapsed value moving without churning the
/// cubit; it stops when the scan ends and this widget is disposed.
class _ScanTimings extends StatefulWidget {
  const _ScanTimings({required this.startTime, required this.etaSecs});
  final DateTime? startTime;
  final int? etaSecs;

  @override
  State<_ScanTimings> createState() => _ScanTimingsState();
}

class _ScanTimingsState extends State<_ScanTimings> {
  static const _elapsedTick = Duration(seconds: 1);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_elapsedTick, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startTime;
    final eta = widget.etaSecs;
    final muted = context.bullType.label
        .copyWith(fontWeight: FontWeight.w400)
        .copyWith(color: context.appColors.textMuted);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (start != null)
          Text(
            context.loc.spScanElapsed(
              formatDuration(
                context.loc,
                DateTime.now().difference(start).inSeconds,
              ),
            ),
            style: muted,
          ),
        if (eta != null)
          Text(
            context.loc.spScanEtaRemaining(formatDuration(context.loc, eta)),
            style: muted,
          ),
      ],
    );
  }
}

String _phaseLabel(BuildContext context, SpScanPhase phase) => switch (phase) {
  SpScanPhase.receive => context.loc.spScanPhaseReceiving,
  SpScanPhase.spend => context.loc.spScanPhaseCheckingSpends,
};

/// The bottom-pinned secondary action shared by every scan-page view.
class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: BullButton.secondary(label: label, onPressed: onPressed),
    );
  }
}

/// Whether scanning continues on its own, shown on every scan-page state so the
/// answer does not depend on how far behind the wallet happens to be.
class _AutoScanStatus extends StatelessWidget {
  const _AutoScanStatus({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.appColors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isEnabled ? Icons.autorenew : Icons.pan_tool_alt_outlined,
            size: 16,
            color: context.appColors.textMuted,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              isEnabled
                  ? context.loc.spScanAutoScanOn
                  : context.loc.spScanCaughtUpManualDetail,
              style: context.bullType.label
                  .copyWith(fontWeight: FontWeight.w400)
                  .copyWith(color: context.appColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
