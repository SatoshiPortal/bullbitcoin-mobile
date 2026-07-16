import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';
import 'package:bb_mobile/features/sp/presentation/scan_start_ticks.dart';
import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpScanScreen extends StatelessWidget {
  const SpScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.loc.spScan, style: context.font.headlineMedium),
      ),
      body: SafeArea(
        child: BlocConsumer<SpCubit, SpState>(
          listenWhen: (previous, current) =>
              previous.isScanning &&
              !current.isScanning &&
              current.scanLastDurationSecs != null &&
              current.error == null,
          listener: (context, state) =>
              unawaited(Navigator.of(context).maybePop()),
          builder: (context, state) {
            if (state.isScanning) return const _ScanningView();
            if (state.error != null) {
              return _ErrorView(message: state.error!.toTranslated(context));
            }
            if (!state.hasScannedBefore) return _FirstScanView(state: state);
            if (state.isCaughtUp) {
              return _CaughtUpView(
                tip: state.chainTip!,
                lastDurationSecs: state.scanLastDurationSecs,
              );
            }
            return _ResumeView(state: state);
          },
        ),
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: BlocBuilder<SpCubit, SpState>(
              builder: (context, state) => _ScanProgressCard(state: state),
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStopButton,
          onPressed: () => unawaited(context.read<SpCubit>().stopScan()),
          bgColor: context.appColors.error,
          textColor: context.appColors.onError,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

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
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.retry,
          onPressed: () => context.read<SpCubit>().scan(),
        ),
      ],
    );
  }
}

class _CaughtUpView extends StatelessWidget {
  const _CaughtUpView({required this.tip, this.lastDurationSecs});
  final int tip;
  final int? lastDurationSecs;

  @override
  Widget build(BuildContext context) {
    final duration = lastDurationSecs;
    return Column(
      children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => context.read<SpCubit>().dismissScanCaughtUp(),
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
                    context.loc.spScanCaughtUpAtBlock('$tip'),
                    style: context.font.titleMedium?.copyWith(
                      color: context.appColors.success,
                    ),
                  ),
                  if (duration != null) ...[
                    const Gap(8),
                    Text(
                      context.loc.spScanScannedIn(
                        formatDuration(context.loc, duration),
                      ),
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStartButton,
          onPressed: () => context.read<SpCubit>().scan(),
        ),
      ],
    );
  }
}

class _ResumeView extends StatelessWidget {
  const _ResumeView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastScannedHeight;
    final tip = state.chainTip;
    final gap = (last != null && tip != null && tip > last) ? tip - last : 0;
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
                  context.loc.spScanBlocksBehind(gap),
                  style: context.font.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                Text(
                  context.loc.spScanApproxDuration(
                    blocksToApproxDuration(
                      context.loc,
                      gap,
                      blocksPerDay: SpConfig.blocksPerDay,
                    ),
                  ),
                  style: context.font.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (state.scanLastDurationSecs != null) ...[
                  const Gap(8),
                  Text(
                    context.loc.spScanScannedIn(
                      formatDuration(context.loc, state.scanLastDurationSecs!),
                    ),
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStartButton,
          onPressed: () => context.read<SpCubit>().scan(),
        ),
      ],
    );
  }
}

/// First-ever scan. When the chain bounds are known, offer the start-height
/// chooser; otherwise fall back to a plain start from the birthday height.
class _FirstScanView extends StatelessWidget {
  const _FirstScanView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final min = state.minBirthdayHeight;
    final tip = state.chainTip;
    if (min != null && tip != null && tip > min) {
      return _ScanStartChooser(
        minBirthday: min,
        tip: tip,
        onStart: (h) => context.read<SpCubit>().scan(startHeight: h),
      );
    }
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.loc.spScanReadyMessage,
                style: context.font.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStartButton,
          onPressed: () => context.read<SpCubit>().scan(),
        ),
      ],
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
                  style: context.font.bodyMedium,
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
                  onChanged: (v) => _setHeight(v.round()),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in ticks)
                      OutlinedButton(
                        onPressed: () => _setHeight(t.height),
                        child: Text(t.label),
                      ),
                  ],
                ),
                const Gap(24),
                Text(
                  context.loc.spScanBlockHeightLabel,
                  style: context.font.bodyMedium,
                ),
                const Gap(8),
                BBInputText(
                  controller: _controller,
                  value: _controller.text,
                  digitsOnly: true,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) _setHeight(parsed, syncField: false);
                  },
                ),
              ],
            ),
          ),
        ),
        _BottomAction(
          label: context.loc.spScanStartFromButton('$_height'),
          onPressed: () => widget.onStart(_height),
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
              phase == SpScanPhase.spend ? '2' : '1',
              '2',
              _phaseLabel(context, phase),
            ),
            style: context.font.titleMedium,
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
                style: context.font.titleMedium,
              ),
            ],
          ),
        ),
        const Gap(16),
        Text(
          current != null && target != null
              ? context.loc.spScanProgressCount('$current', '$target')
              : context.loc.spScanScanning,
          style: context.font.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(4),
        Text(
          context.loc.spScanBlocksLabel,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
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
    final muted = context.font.bodySmall?.copyWith(
      color: context.appColors.textMuted,
    );
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

/// The bottom-pinned action button shared by every scan-page view. Defaults to
/// the secondary colours; the stop action overrides them.
class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.onPressed,
    this.bgColor,
    this.textColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: BBButton.big(
        label: label,
        onPressed: onPressed,
        bgColor: bgColor ?? context.appColors.secondary,
        textColor: textColor ?? context.appColors.onSecondary,
      ),
    );
  }
}
