import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/presentation/recoverbull_failure_l10n.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/password_input_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_provider_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:tor/tor.dart' as tor;

/// How long a blockage must persist before it is shown as a failure.
///
/// Tor restarts its directory fetch as soon as the current directory becomes
/// usable, which briefly drops readiness — a real observed dip was 100% to 45%
/// and back within 173 ms. Without this delay that healthy refresh would put an
/// error and a Retry button on screen.
const _blockageGrace = Duration(seconds: 5);

/// How long the progress bar survives without the fraction moving.
///
/// The fraction is 85% directory completeness, and the directory is cached on
/// disk: with a warm cache and no connectivity at all it reads 0.85 from the
/// first frame. A bar that only appears while the number is actually moving
/// cannot make that claim.
const _progressStale = Duration(seconds: 15);

/// When to start reassuring the user that the wait is normal.
///
/// The directory phase is 85% of the bootstrap budget and reports progress only
/// a handful of times — a measured cold start went 43 s between two updates —
/// so past this point the screen looks stalled even though it is not.
const _reassureAfter = Duration(seconds: 20);

class ConnectingPage extends StatefulWidget {
  const ConnectingPage({super.key});

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage> {
  /// Ticks the elapsed counter. During the long directory phase this is the
  /// only thing on screen that actually moves, so it carries the whole sense
  /// of progress.
  Timer? _ticker;
  final _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;

  /// When the current user-visible blockage first appeared, for [_blockageGrace].
  DateTime? _blockageSince;

  /// When the bootstrap fraction last actually changed, for [_progressStale].
  DateTime? _fractionMovedAt;
  double? _lastFraction;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onStateChanged(BuildContext context, RecoverBullState state) {
    final connection = state.torConnection;
    final now = DateTime.now();

    final fraction = switch (connection) {
      tor.TorConnecting(:final progress) => progress,
      _ => null,
    };
    if (fraction != null && _lastFraction != fraction) {
      _lastFraction = fraction;
      _fractionMovedAt = now;
    }

    final diagnostic = switch (connection) {
      tor.TorConnecting(:final diagnostic) => diagnostic,
      _ => null,
    };
    if (diagnostic == null) {
      _blockageSince = null;
    } else {
      _blockageSince ??= now;
    }

    if (connection is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.online) {
      final hasPreSelectedVault = state.vault != null;
      final nextPage = switch (state.flow) {
        RecoverBullFlow.secureVault => const PasswordInputPage(),
        _ =>
          hasPreSelectedVault
              ? const PasswordInputPage()
              : const VaultProviderSelectionPage(),
      };

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => nextPage));
    }
  }

  /// Whether a blockage has lasted long enough to be worth showing.
  bool get _blockageIsSettled {
    final since = _blockageSince;
    return since != null && DateTime.now().difference(since) >= _blockageGrace;
  }

  /// Whether the fraction is moving, and so worth drawing as a bar.
  bool get _progressIsLive {
    final at = _fractionMovedAt;
    return at != null && DateTime.now().difference(at) < _progressStale;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoverBullBloc, RecoverBullState>(
      listenWhen: (previous, current) =>
          previous.torConnection != current.torConnection ||
          previous.keyServerStatus != current.keyServerStatus,
      listener: _onStateChanged,
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<RecoverBullBloc, RecoverBullState>(
              // Centred when it fits, scrollable when it does not — without
              // ever measuring the body's intrinsic height. `BBText` degrades
              // to `AutoSizeText`, which is a `LayoutBuilder`, and asking a
              // `LayoutBuilder` for intrinsics throws during layout: that is
              // what left this screen blank for the whole bootstrap.
              builder: (context, state) => LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: _Body(
                      state: state,
                      elapsed: _elapsed,
                      showBlockage: _blockageIsSettled,
                      progressIsLive: _progressIsLive,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where each of the three phases stands.
enum _PhaseState { pending, active, done, failed }

class _Body extends StatelessWidget {
  final RecoverBullState state;
  final Duration elapsed;
  final bool showBlockage;
  final bool progressIsLive;

  const _Body({
    required this.state,
    required this.elapsed,
    required this.showBlockage,
    required this.progressIsLive,
  });

  tor.TorConnectionState get _tor => state.torConnection;

  /// The blockage worth acting on, once it has outlived the grace period.
  tor.TorDiagnostic? get _diagnostic {
    if (!showBlockage) return null;
    return switch (_tor) {
      tor.TorConnecting(:final diagnostic) => diagnostic,
      _ => null,
    };
  }

  /// There is deliberately no separate "internet" phase.
  ///
  /// Nothing in the data can carry one honestly: upstream's connectivity flag is
  /// tri-state and its "no blockage" answer covers both "fine" and "too early to
  /// say", so the only positive proof of connectivity is Tor being ready — the
  /// very thing the next row already reports. A missing network shows up here
  /// instead, as the reason Tor is stuck.
  _PhaseState get _torPhase {
    return switch (_tor) {
      tor.TorReady() => _PhaseState.done,
      tor.TorUnavailable() => _PhaseState.failed,
      tor.TorConnecting() => _PhaseState.active,
      tor.TorUninitialized() || tor.TorStopped() => _PhaseState.pending,
    };
  }

  _PhaseState get _serverPhase {
    return switch (state.keyServerStatus) {
      KeyServerStatus.online => _PhaseState.done,
      KeyServerStatus.offline => _PhaseState.failed,
      KeyServerStatus.connecting =>
        _tor is tor.TorReady ? _PhaseState.active : _PhaseState.pending,
      KeyServerStatus.unknown => _PhaseState.pending,
    };
  }

  bool get _hasFailure =>
      _torPhase == _PhaseState.failed || _serverPhase == _PhaseState.failed;

  /// One message, chosen by what actually failed.
  ///
  /// The wording stays hedged for the network diagnoses: upstream documents
  /// them as best effort that "may declare that Arti is stuck for reasons that
  /// are incorrect", so the screen offers an explanation and never asserts.
  String _failureMessage(BuildContext context) {
    final diagnostic = _diagnostic;
    if (diagnostic != null) {
      if (diagnostic.suggestsCensorship) {
        return context.loc.torSettingsDescCensored;
      }
      return switch (diagnostic) {
        tor.TorDiagnostic.offline => context.loc.recoverbullTorOffline,
        tor.TorDiagnostic.clockSkewed => context.loc.recoverbullTorClockSkewed,
        tor.TorDiagnostic.filtering ||
        tor.TorDiagnostic.cantReachTor => context.loc.torSettingsDescCensored,
        tor.TorDiagnostic.cantBootstrap ||
        tor.TorDiagnostic.unknown => context.loc.recoverbullTorCantStart,
      };
    }

    // Only blame the server when Tor actually reached readiness. Otherwise the
    // server never got a working proxy to go through, and telling the user
    // "Tor is working" would be false — the shape of a bug seen in testing,
    // where a torn-down Tor still produced a server-side error message.
    if (_serverPhase == _PhaseState.failed) {
      return _torPhase == _PhaseState.done
          ? context.loc.recoverbullServerUnreachableTorOk
          : context.loc.recoverbullTorCantStart;
    }

    return state.failure?.toTranslated(context) ??
        context.loc.recoverbullConnectionFailed;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        BBText(
          context.loc.recoverbullCheckingConnection,
          textAlign: .center,
          style: context.font.headlineLarge?.copyWith(fontWeight: .bold),
        ),
        const Gap(32),
        _PhaseCard(
          label: context.loc.recoverbullTorNetwork,
          phase: _torPhase,
          // No sub-step is named: the conn/dir split that would identify the
          // exact phase is private upstream, so claiming one would be wrong
          // about a third of the time.
          caption: _torPhase == _PhaseState.active
              ? context.loc.recoverbullPhaseNetworkInfo
              : null,
          // Only drawn while the number is genuinely moving — a cached
          // directory reports 0.85 with no connectivity whatsoever.
          fraction: _torPhase == _PhaseState.active && progressIsLive
              ? switch (_tor) {
                  tor.TorConnecting(:final progress) => progress,
                  _ => null,
                }
              : null,
          elapsed: _torPhase == _PhaseState.active ? elapsed : null,
        ),
        const Gap(8),
        _PhaseCard(
          label: context.loc.recoverbullRecoverBullServer,
          phase: _serverPhase,
          elapsed: _serverPhase == _PhaseState.active ? elapsed : null,
          // Bare "2/3", deliberately unlocalised, like the timer.
          trailingDetail:
              _serverPhase == _PhaseState.active && state.keyServerAttempt > 0
              ? '${state.keyServerAttempt}/${state.keyServerAttempts}'
              : null,
        ),
        const Gap(24),
        if (_hasFailure)
          _FailurePanel(
            message: _failureMessage(context),
            // A single event: `OnTorInitialization` chains to the server check
            // itself, and `restart` guarantees a stuck client is replaced rather
            // than adopted — which is what left a retry waiting on a dead
            // bootstrap after the network came back.
            onRetry: () {
              final bloc = context.read<RecoverBullBloc>();
              if (_tor is tor.TorReady) {
                bloc.add(const OnServerCheck());
              } else {
                bloc.add(const OnTorInitialization(restart: true));
              }
            },
          )
        else
          BBText(
            elapsed >= _reassureAfter
                ? context.loc.recoverbullLongestStep
                : context.loc.recoverbullPleaseWait,
            textAlign: .center,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
            maxLines: 3,
          ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final String label;
  final _PhaseState phase;
  final String? caption;
  final double? fraction;
  final Duration? elapsed;

  /// An extra language-neutral token for the detail line, such as `2/3`.
  final String? trailingDetail;

  const _PhaseCard({
    required this.label,
    required this.phase,
    this.caption,
    this.fraction,
    this.elapsed,
    this.trailingDetail,
  });

  Color _color(BuildContext context) => switch (phase) {
    _PhaseState.done => context.appColors.success,
    _PhaseState.failed => context.appColors.error,
    _PhaseState.active || _PhaseState.pending => context.appColors.textMuted,
  };

  String _statusLabel(BuildContext context) => switch (phase) {
    _PhaseState.done => context.loc.recoverbullConnected,
    _PhaseState.failed => context.loc.recoverbullFailed,
    _PhaseState.active => context.loc.recoverbullConnecting,
    _PhaseState.pending => context.loc.recoverbullWaiting,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              _PhaseIcon(phase: phase, color: color),
              const Gap(12),
              Expanded(
                child: BBText(
                  label,
                  style: context.font.bodyLarge?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
              ),
              BBText(
                _statusLabel(context),
                style: context.font.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: .w600,
                ),
              ),
            ],
          ),
          if (caption != null ||
              fraction != null ||
              elapsed != null ||
              trailingDetail != null) ...[
            const Gap(8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (caption != null)
                    BBText(
                      caption!,
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      maxLines: 2,
                    ),
                  if (fraction != null) ...[
                    const Gap(6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction!.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: context.appColors.onSurface.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                  if (fraction != null ||
                      elapsed != null ||
                      trailingDetail != null) ...[
                    const Gap(6),
                    BBText(
                      [
                        if (fraction != null)
                          context.loc.torSettingsBootstrapProgress(
                            (fraction! * 100).round(),
                          ),
                        ?trailingDetail,
                        // A bare timer, deliberately unlocalised: no words to
                        // translate, and it is the only element that keeps
                        // moving during the long directory phase.
                        if (elapsed != null) _formatElapsed(elapsed!),
                      ].join('  ·  '),
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PhaseIcon extends StatelessWidget {
  final _PhaseState phase;
  final Color color;

  const _PhaseIcon({required this.phase, required this.color});

  @override
  Widget build(BuildContext context) {
    if (phase == _PhaseState.active) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return Icon(
      switch (phase) {
        _PhaseState.done => Icons.check_circle,
        _PhaseState.failed => Icons.error,
        _PhaseState.pending => Icons.circle_outlined,
        _PhaseState.active => Icons.hourglass_empty,
      },
      size: 20,
      color: color,
    );
  }
}

class _FailurePanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailurePanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BBText(
          message,
          textAlign: .center,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.error,
          ),
          maxLines: 4,
        ),
        const Gap(24),
        BBButton.big(
          label: context.loc.recoverbullRetry,
          textStyle: context.font.headlineLarge,
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
