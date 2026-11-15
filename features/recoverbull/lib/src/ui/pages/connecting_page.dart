import 'dart:async';

import 'package:bull_tor/tor.dart' as tor;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/recoverbull_flow.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../recoverbull_flow_navigator.dart';
import '../widgets/backup_monitoring_panel.dart';
import '../widgets/recoverbull_widgets.dart';
import 'password_input_page.dart';
import 'vault_provider_selection_page.dart';

/// How long a blockage must persist before it is shown as a failure.
///
/// Tor briefly drops readiness while it refreshes its directory; without this
/// delay that healthy refresh would put an error and a Retry button on screen.
const _blockageGrace = Duration(seconds: 5);

/// When to start reassuring the user that the wait is normal.
const _reassureAfter = Duration(seconds: 20);

/// Shows Tor and key-server readiness, then hands over to the flow's first step.
class ConnectingPage extends StatefulWidget {
  const ConnectingPage({super.key});

  @override
  State<ConnectingPage> createState() => _ConnectingPageState();
}

class _ConnectingPageState extends State<ConnectingPage> {
  Timer? _ticker;

  /// Start of the phase currently on screen, not of the page.
  DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  bool? _torPhaseWasActive;
  DateTime? _blockageSince;

  /// Readiness is reported more than once; navigate only the first time.
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<VaultFlowCubit>();
      _onStateChanged(context, cubit.state);
      if (cubit.state.keyServer != KeyServerStatus.online) {
        unawaited(cubit.connect());
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _resetWait() {
    setState(() {
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
    });
  }

  void _onStateChanged(BuildContext context, VaultFlowState state) {
    if (_hasNavigated) return;
    final connection = state.tor;
    final now = DateTime.now();
    final diagnostic = switch (connection) {
      tor.TorConnecting(:final diagnostic) => diagnostic,
      _ => null,
    };
    setState(() {
      if (diagnostic == null) {
        _blockageSince = null;
      } else {
        _blockageSince ??= now;
      }
      // Hand the clock over when Tor stops being the active phase.
      final torIsActive = connection is! tor.TorReady;
      if (_torPhaseWasActive != null && _torPhaseWasActive != torIsActive) {
        _startedAt = now;
        _elapsed = Duration.zero;
      }
      _torPhaseWasActive = torIsActive;
    });

    if (state.keyServer == KeyServerStatus.online) {
      _hasNavigated = true;
      final scope = RecoverBullFlowScope.of(context);
      final Widget next = switch (scope.flow) {
        RecoverBullFlow.secureVault => const PasswordInputPage(),
        _ when state.vault != null => const PasswordInputPage(),
        _ => const VaultProviderSelectionPage(),
      };
      unawaited(
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: (_) => next)),
      );
    }
  }

  bool get _blockageIsSettled {
    final since = _blockageSince;
    return since != null && DateTime.now().difference(since) >= _blockageGrace;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VaultFlowCubit, VaultFlowState>(
      listenWhen: (previous, current) =>
          previous.tor != current.tor ||
          previous.keyServer != current.keyServer,
      listener: _onStateChanged,
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          leading: IconButton(
            onPressed: () => recoverBullBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<VaultFlowCubit, VaultFlowState>(
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
                      onRetry: _resetWait,
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

enum _PhaseState { pending, active, done, failed }

class _Body extends StatelessWidget {
  final VaultFlowState state;
  final Duration elapsed;
  final bool showBlockage;
  final VoidCallback onRetry;

  const _Body({
    required this.state,
    required this.elapsed,
    required this.showBlockage,
    required this.onRetry,
  });

  tor.TorConnectionState get _tor => state.tor;

  tor.TorDiagnostic? get _diagnostic {
    if (!showBlockage) return null;
    return switch (_tor) {
      tor.TorConnecting(:final diagnostic) => diagnostic,
      _ => null,
    };
  }

  tor.TorDiagnostic? get _failureDiagnostic => switch (_tor) {
    tor.TorUnavailable(failure: tor.TorBootstrapFailure(:final diagnostic)) =>
      diagnostic,
    _ => null,
  };

  /// A user-managed proxy never reports embedded readiness: a reachable
  /// server is then the proof that Tor works.
  _PhaseState get _torPhase {
    if (state.keyServer == KeyServerStatus.online) return _PhaseState.done;
    return switch (_tor) {
      tor.TorReady() => _PhaseState.done,
      tor.TorUnavailable() => _PhaseState.failed,
      tor.TorConnecting() => _PhaseState.active,
      tor.TorUninitialized() || tor.TorStopped() =>
        state.keyServer == KeyServerStatus.connecting
            ? _PhaseState.active
            : _PhaseState.pending,
    };
  }

  _PhaseState get _serverPhase => switch (state.keyServer) {
    KeyServerStatus.online => _PhaseState.done,
    KeyServerStatus.offline => _PhaseState.failed,
    KeyServerStatus.connecting =>
      _tor is tor.TorReady ? _PhaseState.active : _PhaseState.pending,
    KeyServerStatus.unknown => _PhaseState.pending,
  };

  bool get _hasFailure =>
      _torPhase == _PhaseState.failed ||
      _serverPhase == _PhaseState.failed ||
      _diagnostic != null;

  /// The failure panel stays up while a retry runs, so its buttons show as disabled instead of vanishing.
  bool get _showFailurePanel =>
      _hasFailure ||
      (state.keyServerFailures > 0 &&
          state.keyServer == KeyServerStatus.connecting);

  /// Only an embedded route can take another path.
  bool get _offersNewCircuit =>
      state.keyServerFailures >= 1 &&
      switch (_tor) {
        tor.TorReady(:final route) => route.source == tor.TorSource.embedded,
        _ => false,
      };

  TorBullState get _mascotState {
    final diagnostic = _diagnostic;
    if (diagnostic?.suggestsCensorship ?? false) return TorBullState.filtered;
    if (_hasFailure) return TorBullState.failed;
    if (_tor is tor.TorReady) return TorBullState.ready;
    return switch (_tor) {
      tor.TorConnecting(transport: tor.TorTransport.snowflake) =>
        TorBullState.snowflake,
      tor.TorUninitialized() || tor.TorStopped() =>
        state.keyServer == KeyServerStatus.connecting
            ? TorBullState.direct
            : TorBullState.idle,
      tor.TorReady() ||
      tor.TorConnecting() ||
      tor.TorUnavailable() => TorBullState.direct,
    };
  }

  String _connectionNarrative(BuildContext context) {
    if (_tor is tor.TorReady && state.keyServer != KeyServerStatus.online) {
      return context.loc.recoverbullConnectingTor;
    }
    return switch (_mascotState) {
      TorBullState.direct => context.loc.torSettingsModeDirectDescription,
      TorBullState.filtered => [
        context.loc.torSettingsDescCensored,
        context.loc.torSettingsModeAutomaticDescription,
      ].join(' '),
      TorBullState.snowflake => context.loc.torSettingsModeSnowflakeDescription,
      TorBullState.ready => context.loc.torSettingsDescConnected,
      TorBullState.failed => _failureMessage(context),
      TorBullState.idle => context.loc.recoverbullPleaseWait,
    };
  }

  /// One message, chosen by what actually failed.
  String _failureMessage(BuildContext context) {
    final diagnostic = _diagnostic ?? _failureDiagnostic;
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
    if (_serverPhase == _PhaseState.failed) {
      // Only blame the server when Tor actually reached readiness.
      if (_tor is! tor.TorReady && _tor is! tor.TorUninitialized) {
        return context.loc.recoverbullTorCantStart;
      }
      return switch (state.failure) {
        KeyServerFailure(kind: KeyServerFailureKind.timeout) =>
          context.loc.recoverbullServerCircuitTimeout,
        KeyServerFailure(kind: KeyServerFailureKind.unavailable) =>
          context.loc.recoverbullServerOnionUnreachable,
        KeyServerFailure(kind: KeyServerFailureKind.badResponse) =>
          context.loc.recoverbullServerBadResponse,
        KeyServerFailure(kind: KeyServerFailureKind.rejected) =>
          context.loc.recoverbullErrorRejected,
        final failure? => failure.toTranslated(context),
        null => context.loc.recoverbullServerUnreachableTorOk,
      };
    }
    return state.failure?.toTranslated(context) ??
        context.loc.recoverbullConnectionFailed;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VaultFlowCubit>();
    final monitoring = RecoverBullFlowScope.of(context).presentation.monitoring;
    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        if (monitoring != null)
          BackupMonitoringPanel(cubit: monitoring, alertsOnly: true),
        Center(
          child: TorBullMascot(
            state: _mascotState,
            semanticLabel: context.loc.recoverbullTorNetwork,
          ),
        ),
        const Gap(12),
        BullText(
          context.loc.recoverbullCheckingConnection,
          textAlign: .center,
          style: context.bullText.headlineLarge?.copyWith(fontWeight: .bold),
        ),
        const Gap(12),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (_mascotState == TorBullState.filtered)
                    BullText(
                      context.loc.torSettingsStatusCensored,
                      textAlign: .center,
                      style: context.bullText.bodyLarge?.copyWith(
                        color: context.bull.warning,
                        fontWeight: .w700,
                      ),
                    ),
                  if (_mascotState == TorBullState.snowflake)
                    BullText(
                      context.loc.torSettingsActiveTransport(
                        context.loc.torSettingsModeSnowflake,
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
        _PhaseCard(
          label: context.loc.recoverbullTorNetwork,
          phase: _torPhase,
          activeLabel: context.loc.recoverbullTorInitializing,
          doneLabel: context.loc.recoverbullTorReady,
          caption: _torPhase == _PhaseState.active
              ? context.loc.recoverbullPhaseNetworkInfo
              : null,
          elapsed: _torPhase == _PhaseState.active ? elapsed : null,
        ),
        const Gap(8),
        _PhaseCard(
          label: context.loc.recoverbullRecoverBullServer,
          phase: _serverPhase,
          elapsed: _serverPhase == _PhaseState.active ? elapsed : null,
        ),
        const Gap(24),
        if (_showFailurePanel)
          _FailurePanel(
            busy: !_hasFailure,
            message: _failureMessage(context),
            onRetry: () {
              onRetry();
              unawaited(cubit.connect());
            },
            onNewCircuit: _offersNewCircuit
                ? () {
                    onRetry();
                    unawaited(cubit.connect(newRoute: true));
                  }
                : null,
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
}

class _PhaseCard extends StatelessWidget {
  final String label;
  final _PhaseState phase;
  final String? caption;
  final Duration? elapsed;
  final String? activeLabel;
  final String? doneLabel;

  const _PhaseCard({
    required this.label,
    required this.phase,
    this.activeLabel,
    this.doneLabel,
    this.caption,
    this.elapsed,
  });

  Color _color(BuildContext context) => switch (phase) {
    _PhaseState.done => context.bull.success,
    _PhaseState.failed => context.bull.error,
    _PhaseState.active || _PhaseState.pending => context.bull.textMuted,
  };

  String _statusLabel(BuildContext context) => switch (phase) {
    _PhaseState.done => doneLabel ?? context.loc.recoverbullConnected,
    _PhaseState.failed => context.loc.recoverbullFailed,
    _PhaseState.active => activeLabel ?? context.loc.recoverbullConnecting,
    _PhaseState.pending => context.loc.recoverbullWaiting,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.bull.surface,
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
          if (caption != null || elapsed != null) ...[
            const Gap(8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (caption case final caption?)
                    BullText(
                      caption,
                      style: context.bullText.bodySmall?.copyWith(
                        color: context.bull.textMuted,
                      ),
                      maxLines: 2,
                    ),
                  if (elapsed case final elapsed?) ...[
                    const Gap(6),
                    BullText(
                      // A bare timer, deliberately unlocalised.
                      _formatElapsed(elapsed),
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
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback? onNewCircuit;

  const _FailurePanel({
    required this.message,
    required this.onRetry,
    this.busy = false,
    this.onNewCircuit,
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
        const Gap(24),
        BullButton.big(
          label: context.loc.recoverbullRetry,
          textStyle: context.bullText.headlineLarge,
          bgColor: context.bull.onSurface,
          textColor: context.bull.surface,
          disabled: busy,
          onPressed: onRetry,
        ),
        if (onNewCircuit case final onNewCircuit?) ...[
          const Gap(12),
          BullButton.big(
            label: context.loc.recoverbullNewRoute,
            textStyle: context.bullText.headlineLarge,
            bgColor: context.bull.surface,
            textColor: context.bull.onSurface,
            outlined: true,
            borderColor: context.bull.onSurface,
            disabled: busy,
            onPressed: onNewCircuit,
          ),
        ],
      ],
    );
  }
}
