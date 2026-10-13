import '../../domain/recoverbull_navigation_port.dart';
import 'dart:async';

import '../../presentation/bloc.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../domain/recoverbull_failure.dart';
import './password_input_page.dart';
import './vault_provider_selection_page.dart';
import '../widgets/tor_bull_mascot.dart';
import '../../router/flow_type.dart';
import '../../l10n/context_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_tor/tor.dart' as tor;

/// How long a blockage must persist before it is shown as a failure.
///
/// Tor restarts its directory fetch as soon as the current directory becomes
/// usable, which briefly drops readiness — a real observed dip was 100% to 45%
/// and back within 173 ms. Without this delay that healthy refresh would put an
/// error and a Retry button on screen.
const _blockageGrace = Duration(seconds: 5);

/// When to start reassuring the user that the wait is normal.
///
/// The directory phase is 85% of the bootstrap budget and reports progress only
/// a handful of times — a measured cold start went 43 s between two updates —
/// so past this point the screen looks stalled even though it is not.
const _reassureAfter = Duration(seconds: 20);

class ConnectingPage extends StatefulWidget {
  final DateTime Function() now;

  const ConnectingPage({super.key, this.now = DateTime.now});

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage> {
  /// Ticks the elapsed counter. During the long directory phase this is the
  /// only thing on screen that actually moves, so it carries the whole sense
  /// of progress.
  Timer? _ticker;

  /// Start of the current connection attempt.
  late DateTime _startedAt;
  Duration _elapsed = Duration.zero;

  /// When the current user-visible blockage first appeared, for [_blockageGrace].
  DateTime? _blockageSince;

  /// Whether this screen has already handed the flow to the next page.
  ///
  /// Readiness is not a single event: Tor republishes `TorReady` on every
  /// directory refresh, and the key-server check emits its own states, so the
  /// success condition below is satisfied more than once. Without this guard
  /// each repetition pushed another route, stacking duplicate pages behind the
  /// one the user sees.
  bool _hasNavigated = false;
  bool _hasSeenReady = false;

  @override
  void initState() {
    super.initState();
    _startedAt = widget.now();
    _hasSeenReady =
        context.read<RecoverBullBloc>().state.torConnection is tor.TorReady;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = widget.now().difference(_startedAt));
    });

    // `BlocListener` only sees emissions after it subscribes, so a blockage
    // already present at mount would not start the grace clock until arti
    // happened to re-emit. Seeding from the current state removes that
    // dependency.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onStateChanged(context, context.read<RecoverBullBloc>().state);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onStateChanged(BuildContext context, RecoverBullState state) {
    if (_hasNavigated) return;

    final connection = state.torConnection;
    final now = widget.now();
    if (connection is tor.TorReady) _hasSeenReady = true;

    final diagnostic = switch (connection) {
      tor.TorConnecting(:final diagnostic) => diagnostic,
      _ => null,
    };

    // `build` reads this through `_blockageIsSettled`, so it is widget state,
    // not bookkeeping. Mutating it bare only appeared to work because the
    // one-second ticker rebuilt anyway.
    setState(() {
      if (diagnostic == null) {
        _blockageSince = null;
      } else {
        _blockageSince ??= now;
      }
    });

    if (connection is tor.TorReady &&
        state.keyServerStatus == KeyServerStatus.online) {
      _hasNavigated = true;
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

  void _onRetry() {
    // This is the only explicit reset signal. Tor phase changes and Arti
    // republications belong to the same user-visible attempt.
    //
    // The blockage clock is left alone: initialization is droppable, so a
    // retry during an active attempt can produce no new state, and clearing it
    // here would hide a diagnostic that is still current. It clears when the
    // diagnostic does.
    setState(() {
      _startedAt = widget.now();
      _elapsed = Duration.zero;
    });
    final bloc = context.read<RecoverBullBloc>();
    if (bloc.state.torConnection case tor.TorReady(
      :final route,
    ) when route.source == tor.TorSource.embedded) {
      bloc.add(const OnServerCheck());
    } else {
      bloc.add(const OnTorInitialization(restart: true));
    }
  }

  /// Whether a blockage has lasted long enough to be worth showing.
  bool get _blockageIsSettled {
    final since = _blockageSince;
    return since != null && widget.now().difference(since) >= _blockageGrace;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoverBullBloc, RecoverBullState>(
      listenWhen: (previous, current) =>
          previous.torConnection != current.torConnection ||
          previous.keyServerStatus != current.keyServerStatus,
      listener: _onStateChanged,
      child: BullScaffold(
        appBar: BullTopBar.appBar(
          title: '',
          onBack: () => context.pop(),
          materialTransparency: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<RecoverBullBloc, RecoverBullState>(
              // Centred when it fits, scrollable when it does not — without
              // ever measuring the body's intrinsic height. `BullText` degrades
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
                      reconnecting: _hasSeenReady,
                      elapsed: _elapsed,
                      showBlockage: _blockageIsSettled,
                      onRetry: _onRetry,
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
  final VoidCallback onRetry;
  final bool reconnecting;

  const _Body({
    required this.state,
    required this.elapsed,
    required this.showBlockage,
    required this.onRetry,
    required this.reconnecting,
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

  /// The blockage a bootstrap reported when it gave up.
  ///
  /// Deliberately not subject to [_blockageGrace]: that grace exists to ride
  /// out a transient readiness dip, and a terminal failure is not one. Without
  /// this the reason was dropped exactly when it stopped being provisional.
  tor.TorDiagnostic? get _failureDiagnostic => switch (_tor) {
    tor.TorUnavailable(failure: tor.TorBootstrapFailure(:final diagnostic)) =>
      diagnostic,
    _ => null,
  };

  /// There is deliberately no separate "internet" phase.
  ///
  /// Nothing in the data can carry one honestly: upstream's connectivity flag is
  /// tri-state and its "no blockage" answer covers both "fine" and "too early to
  /// say", so the only positive proof of connectivity is Tor being ready — the
  /// very thing the next row already reports. A missing network shows up here
  /// instead, as the reason Tor is stuck.
  _PhaseState get _torPhase {
    // The attributed Tor verdict is stronger evidence than Arti's last
    // readiness snapshot: showing "Connected" beside a Tor-attributed
    // failure would present two contradictory claims to the user.
    if (state.failure?.supportCause == 'tor') return _PhaseState.failed;

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
      KeyServerStatus.connecting => _PhaseState.active,
      KeyServerStatus.unknown => _PhaseState.pending,
    };
  }

  /// A settled blockage counts, not just a failed phase.
  ///
  /// Without `_diagnostic` here the whole grace-period mechanism was
  /// unreachable: the explanation is only rendered from the failure panel, and
  /// that panel was gated on a *failed* phase. In the mainline case this screen
  /// exists for — device offline, Tor still `TorConnecting` with a diagnostic,
  /// key server not yet checked — the Tor phase is `active` and the server phase
  /// `pending`, so nothing was shown until the bootstrap gave up minutes later.
  bool get _hasFailure =>
      _torPhase == _PhaseState.failed ||
      _serverPhase == _PhaseState.failed ||
      _diagnostic != null;

  TorBullState get _mascotState {
    final diagnostic = _diagnostic;
    if (diagnostic?.suggestsCensorship ?? false) {
      return TorBullState.filtered;
    }

    if (_hasFailure) return TorBullState.failed;
    if (_tor is tor.TorReady) return TorBullState.ready;

    if (diagnostic != null) {
      return diagnostic.suggestsCensorship
          ? TorBullState.filtered
          : TorBullState.failed;
    }

    return switch (_tor) {
      tor.TorConnecting(transport: tor.TorTransport.snowflake) =>
        TorBullState.snowflake,
      tor.TorUninitialized() || tor.TorStopped() => TorBullState.idle,
      tor.TorReady() ||
      tor.TorConnecting() ||
      tor.TorUnavailable() => TorBullState.direct,
    };
  }

  String _connectionNarrative(BuildContext context) {
    if (_tor is tor.TorReady &&
        state.keyServerStatus != KeyServerStatus.online) {
      return context.loc.recoverbullConnectingTor;
    }

    if (reconnecting && _tor is tor.TorConnecting) {
      return context.loc.recoverbullReconnecting;
    }

    return switch (_mascotState) {
      TorBullState.direct =>
        context.recoverBullLabels.torSettingsModeDirectDescription,
      TorBullState.filtered => [
        context.recoverBullLabels.torSettingsDescCensored,
        context.recoverBullLabels.torSettingsModeAutomaticDescription,
      ].join(' '),
      TorBullState.snowflake =>
        context.recoverBullLabels.torSettingsModeSnowflakeDescription,
      TorBullState.ready => context.recoverBullLabels.torSettingsDescConnected,
      TorBullState.failed => _failureMessage(context),
      TorBullState.idle => context.loc.recoverbullPleaseWait,
    };
  }

  /// One message, chosen by what actually failed.
  ///
  /// The wording stays hedged for the network diagnoses: upstream documents
  /// them as best effort that "may declare that Arti is stuck for reasons that
  /// are incorrect", so the screen offers an explanation and never asserts.
  String _failureMessage(BuildContext context) {
    final diagnostic = _diagnostic ?? _failureDiagnostic;
    if (diagnostic != null) {
      if (diagnostic.suggestsCensorship) {
        return context.recoverBullLabels.torSettingsDescCensored;
      }
      return switch (diagnostic) {
        tor.TorDiagnostic.offline => context.loc.recoverbullTorOffline,
        tor.TorDiagnostic.clockSkewed => context.loc.recoverbullTorClockSkewed,
        tor.TorDiagnostic.filtering || tor.TorDiagnostic.cantReachTor =>
          context.recoverBullLabels.torSettingsDescCensored,
        tor.TorDiagnostic.cantBootstrap ||
        tor.TorDiagnostic.unknown => context.loc.recoverbullTorCantStart,
      };
    }

    final failure = state.failure;
    if (failure?.supportCause != null) {
      return failure!.toTranslated(context);
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
        Center(
          child: TorBullMascot(
            state: _mascotState,
            semanticLabel: context.loc.recoverbullTorNetwork,
          ),
        ),
        const Gap(BullSpacing.sm),
        BullText(
          context.loc.recoverbullCheckingConnection,
          textAlign: .center,
          style: context.bullText.headlineLarge?.copyWith(fontWeight: .bold),
        ),
        const Gap(BullSpacing.sm),
        if (!_hasFailure)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(_mascotState),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: switch (_mascotState) {
                  TorBullState.filtered => context.bull.warningContainer,
                  TorBullState.failed => context.bull.errorContainer,
                  _ => context.bull.surface,
                },
                borderRadius: BorderRadius.circular(BullRadius.md),
              ),
              child: Column(
                children: [
                  if (_mascotState == TorBullState.filtered)
                    BullText(
                      context.recoverBullLabels.torSettingsStatusCensored,
                      textAlign: .center,
                      style: context.bullText.bodyLarge?.copyWith(
                        color: context.bull.warning,
                        fontWeight: .w700,
                      ),
                    ),
                  if (_mascotState == TorBullState.snowflake)
                    BullText(
                      context.recoverBullLabels.torSettingsActiveTransport(
                        context.recoverBullLabels.torSettingsModeSnowflake,
                      ),
                      textAlign: .center,
                      style: context.bullText.bodyLarge?.copyWith(
                        color: context.bull.info,
                        fontWeight: .w700,
                      ),
                    ),
                  BullText(
                    _connectionNarrative(context),
                    textAlign: .center,
                    style: context.bullText.bodySmall?.copyWith(
                      color: context.bull.textMuted,
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
        const Gap(20),
        BullText(
          context.loc.recoverbullElapsedSinceStart(_formatElapsed(elapsed)),
          textAlign: .center,
          style: context.bullText.bodySmall?.copyWith(
            color: context.bull.textMuted,
          ),
        ),
        const Gap(BullSpacing.sm),
        _PhaseCard(
          key: const ValueKey('tor-phase-card'),
          label: context.loc.recoverbullTorNetwork,
          phase: _torPhase,
          // No sub-step is named: the conn/dir split that would identify the
          // exact phase is private upstream, so claiming one would be wrong
          // about a third of the time.
          caption: _torCaption(context),
          statusLabels: _torStatusLabels(context),
        ),
        const Gap(BullSpacing.xs),
        _PhaseCard(
          key: const ValueKey('server-phase-card'),
          label: context.loc.recoverbullRecoverBullServer,
          phase: _serverPhase,
          statusLabels: _serverStatusLabels(context),
          // Bare "2/3", deliberately unlocalised, like the timer.
          trailingDetail:
              _serverPhase == _PhaseState.active && state.keyServerAttempt > 0
              ? '${state.keyServerAttempt}/${state.keyServerAttempts}'
              : null,
        ),
        const Gap(BullSpacing.lg),
        if (_hasFailure)
          _FailurePanel(
            message: _failureMessage(context),
            onOpenTorSettings:
                state.failure is ExternalTorProxyUnavailableFailure
                ? () => context
                      .read<RecoverBullNavigationPort>()
                      .openTorSettings()
                : null,
            // A single event: `OnTorInitialization` chains to the server check
            // itself, and `restart` guarantees a stuck client is replaced rather
            // than adopted — which is what left a retry waiting on a dead
            // bootstrap after the network came back.
            onRetry: onRetry,
          )
        else
          BullText(
            elapsed >= _reassureAfter
                ? context.loc.recoverbullLongestStep
                : context.loc.recoverbullPleaseWait,
            textAlign: .center,
            style: context.bullText.bodyMedium?.copyWith(
              color: context.bull.textMuted,
            ),
            maxLines: 3,
          ),
      ],
    );
  }

  String? _torCaption(BuildContext context) {
    if (_torPhase != _PhaseState.active) {
      return null;
    }
    final (progress, transport) = switch (_tor) {
      tor.TorConnecting(:final progress, :final transport) => (
        progress,
        transport,
      ),
      _ => (null, null),
    };
    final percentage = progress == null ? null : '${(progress * 100).round()}%';
    return [
      context.loc.recoverbullPhaseNetworkInfo,
      ?percentage,
      ?transport?.name,
    ].join(' · ');
  }

  ({String waiting, String active, String done, String failed})
  _torStatusLabels(BuildContext context) => (
    waiting: context.loc.recoverbullWaiting,
    active: context.loc.recoverbullConnecting,
    done: context.loc.recoverbullConnected,
    failed: context.loc.recoverbullFailed,
  );

  ({String waiting, String active, String done, String failed})
  _serverStatusLabels(BuildContext context) => (
    waiting: context.loc.recoverbullWaitingForTor,
    active: context.loc.recoverbullChecking,
    done: context.loc.recoverbullReachable,
    failed: context.loc.recoverbullUnreachable,
  );
}

class _PhaseCard extends StatelessWidget {
  final String label;
  final _PhaseState phase;
  final String? caption;

  /// An extra language-neutral token for the detail line, such as `2/3`.
  final String? trailingDetail;
  final ({String waiting, String active, String done, String failed})
  statusLabels;

  const _PhaseCard({
    super.key,
    required this.label,
    required this.phase,
    this.caption,
    this.trailingDetail,
    required this.statusLabels,
  });

  Color _color(BuildContext context) => switch (phase) {
    _PhaseState.done => context.bull.success,
    _PhaseState.failed => context.bull.error,
    _PhaseState.active || _PhaseState.pending => context.bull.textMuted,
  };

  String _statusLabel(BuildContext context) => switch (phase) {
    _PhaseState.done => statusLabels.done,
    _PhaseState.failed => statusLabels.failed,
    _PhaseState.active => statusLabels.active,
    _PhaseState.pending => statusLabels.waiting,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.bull.surface,
        borderRadius: BorderRadius.circular(BullRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              _PhaseIcon(phase: phase, color: color),
              const Gap(BullSpacing.sm),
              Expanded(
                child: BullText(
                  label,
                  style: context.bullText.bodyLarge?.copyWith(
                    color: context.bull.onSurface,
                  ),
                ),
              ),
              BullText(
                _statusLabel(context),
                style: context.bullText.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: .w600,
                ),
              ),
            ],
          ),
          if (caption != null || trailingDetail != null) ...[
            const Gap(BullSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (caption != null)
                    BullText(
                      caption!,
                      style: context.bullText.bodySmall?.copyWith(
                        color: context.bull.textMuted,
                      ),
                      maxLines: 2,
                    ),
                  if (trailingDetail != null) ...[
                    const Gap(6),
                    BullText(
                      [?trailingDetail].join('  ·  '),
                      style: context.bullText.bodySmall?.copyWith(
                        color: context.bull.textMuted,
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
}

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
  final VoidCallback? onOpenTorSettings;

  const _FailurePanel({
    required this.message,
    required this.onRetry,
    this.onOpenTorSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BullText(
          message,
          textAlign: .center,
          style: context.bullText.bodyMedium?.copyWith(
            color: context.bull.error,
          ),
          maxLines: 4,
        ),
        const Gap(BullSpacing.lg),
        BullButton.big(
          label: context.loc.recoverbullRetry,
          textStyle: context.bullText.headlineLarge,
          bgColor: context.bull.onSurface,
          textColor: context.bull.surface,
          onPressed: onRetry,
        ),
        if (onOpenTorSettings != null) ...[
          const Gap(BullSpacing.sm),
          BullButton.big(
            label: context.recoverBullLabels.torSettingsTitle,
            textStyle: context.bullText.headlineLarge,
            bgColor: context.bull.surface,
            textColor: context.bull.onSurface,
            onPressed: () => onOpenTorSettings!(),
          ),
        ],
      ],
    );
  }
}
