import 'dart:async';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Tab layout, labels and dialogs mirror joinstr-kmp and floresta_wallet:
/// Create New Pool, My Pools, View Other Pools, History; a waiting dialog
/// while a round is in flight; snackbars for outcomes.
class JoinstrScreen extends StatefulWidget {
  const JoinstrScreen({super.key});

  @override
  State<JoinstrScreen> createState() => _JoinstrScreenState();
}

class _JoinstrScreenState extends State<JoinstrScreen> {
  // Snapshot used to fire snackbars exactly once per transition, rather than
  // on every rebuild.
  int _seenRounds = 0;
  JoinstrRoundStatus? _seenTopStatus;
  JoinstrException? _seenError;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.loc.joinstrTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showRelaySettings(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.loc.joinstrTabCreate),
              Tab(text: context.loc.joinstrTabMyPools),
              Tab(text: context.loc.joinstrTabOtherPools),
              Tab(text: context.loc.joinstrTabHistory),
            ],
          ),
        ),
        body: BlocConsumer<JoinstrCubit, JoinstrState>(
          listenWhen: (prev, curr) =>
              prev.rounds.length != curr.rounds.length ||
              _topStatus(prev) != _topStatus(curr) ||
              prev.error != curr.error,
          listener: _onStateChange,
          builder: (context, state) {
            // A wallet-level problem (watch-only, mainnet, none eligible) is
            // terminal: the feature cannot be used, so show it in place rather
            // than as a transient snackbar.
            if (state.wallet == null && state.error != null) {
              return _EmptyState(
                message: joinstrErrorMessage(context, state.error!),
              );
            }
            return TabBarView(
              children: [
                _CreatePoolTab(state: state),
                _MyPoolsTab(rounds: state.rounds),
                _OtherPoolsTab(state: state),
                _HistoryTab(history: state.history),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A coinjoin round is created or joined without blocking the screen: it
  /// runs in the background and shows up on the My Pools tab. This only turns
  /// state transitions into one-shot snackbars, and jumps to My Pools when a
  /// round starts so the user sees the pool they just created/joined.
  JoinstrRoundStatus? _topStatus(JoinstrState state) =>
      state.rounds.isEmpty ? null : state.rounds.first.status;

  void _onStateChange(BuildContext context, JoinstrState state) {
    final top = state.rounds.isEmpty ? null : state.rounds.first;

    if (state.rounds.length > _seenRounds && top != null) {
      _snack(
        context,
        top.initiated
            ? context.loc.joinstrPoolCreatedSnack
            : context.loc.joinstrJoinRequestSnack,
      );
      DefaultTabController.of(context).animateTo(1); // My Pools
    } else if (top != null && top.status != _seenTopStatus) {
      if (top.status == JoinstrRoundStatus.broadcast) {
        _snack(context, context.loc.joinstrCoinjoinBroadcast(top.txId!));
      } else if (top.status == JoinstrRoundStatus.failed) {
        _snack(context, joinstrErrorMessage(context, top.error!));
      }
    } else if (state.wallet != null &&
        state.error != null &&
        state.error != _seenError) {
      _snack(context, joinstrErrorMessage(context, state.error!));
    }

    _seenRounds = state.rounds.length;
    _seenTopStatus = top?.status;
    _seenError = state.error;
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRelaySettings(BuildContext context) {
    final cubit = context.read<JoinstrCubit>();
    final controller = TextEditingController(text: cubit.state.relay);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.joinstrNostrRelay),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'wss://'),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.loc.joinstrCancel),
          ),
          TextButton(
            onPressed: () {
              cubit.relayChanged(controller.text);
              Navigator.of(dialogContext).pop();
            },
            child: Text(dialogContext.loc.joinstrSave),
          ),
        ],
      ),
    );
  }
}

class _CreatePoolTab extends StatelessWidget {
  const _CreatePoolTab({required this.state});

  final JoinstrState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JoinstrCubit>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.loc.joinstrPoolDetails,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(12),
        _FilteredTextField(
          value: state.denominationBtc,
          label: context.loc.joinstrDenomination,
          helper: context.loc.joinstrDenominationSupport,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: cubit.denominationChanged,
        ),
        const Gap(12),
        _FilteredTextField(
          value: state.peers,
          label: context.loc.joinstrPeers,
          keyboardType: TextInputType.number,
          onChanged: cubit.peersChanged,
        ),
        const Gap(12),
        _FilteredTextField(
          value: state.feeRate,
          label: context.loc.joinstrFeeRate,
          keyboardType: TextInputType.number,
          onChanged: cubit.feeRateChanged,
        ),
        const Gap(16),
        FilledButton(
          onPressed:
              state.canInteract &&
                  state.denominationBtc.isNotEmpty &&
                  state.peers.isNotEmpty
              ? cubit.initiatePool
              : null,
          child: Text(context.loc.joinstrCreate),
        ),
        if (state.isRunning) ...[
          const Gap(8),
          Text(
            context.loc.joinstrRoundInProgress,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// A text field that stays in sync with the cubit's filtered value: when the
/// cubit rejects input (a letter in a numeric field), the field snaps back
/// instead of displaying text the state does not hold.
class _FilteredTextField extends StatefulWidget {
  const _FilteredTextField({
    required this.value,
    required this.label,
    required this.keyboardType,
    required this.onChanged,
    this.helper,
  });

  final String value;
  final String label;
  final String? helper;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  State<_FilteredTextField> createState() => _FilteredTextFieldState();
}

class _FilteredTextFieldState extends State<_FilteredTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_FilteredTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _MyPoolsTab extends StatelessWidget {
  const _MyPoolsTab({required this.rounds});

  final List<JoinstrRound> rounds;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return _EmptyState(message: context.loc.joinstrNoActivePools);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rounds.length,
      separatorBuilder: (_, _) => const Gap(12),
      itemBuilder: (context, index) => _RoundCard(round: rounds[index]),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.round});

  final JoinstrRound round;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.joinstrDenominationLine(
                Joinstr.formatBtc(round.denominationSat),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Gap(4),
            Text(loc.joinstrPeersLine(round.peers)),
            Text(
              loc.joinstrRelayLine(round.relay),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (round.publicKey != null)
              Text(
                loc.joinstrPublicKeyLine(_short(round.publicKey!)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const Gap(4),
            switch (round.status) {
              // A pool this device created waits for peers; a pool it is
              // joining waits for the initiator's credentials. These are
              // different states in the protocol and must not read alike.
              JoinstrRoundStatus.waiting => Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      round.initiated
                          ? loc.joinstrWaitingForPeers
                          : loc.joinstrWaitingForCredentials,
                    ),
                  ),
                ],
              ),
              JoinstrRoundStatus.broadcast => Text(
                '${loc.joinstrBroadcast}: ${_short(round.txId!)}',
              ),
              JoinstrRoundStatus.failed => Text(
                joinstrErrorMessage(context, round.error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            },
            if (round.isWaiting) ...[
              const Gap(2),
              _CountdownText(expiresAtUnixSec: round.expiresAtUnixSec),
            ],
          ],
        ),
      ),
    );
  }

  String _short(String value) =>
      value.length <= 20 ? value : '${value.substring(0, 20)}…';
}

class _OtherPoolsTab extends StatelessWidget {
  const _OtherPoolsTab({required this.state});

  final JoinstrState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton(
            onPressed: state.canInteract
                ? () => context.read<JoinstrCubit>().refreshPools()
                : null,
            child: Text(context.loc.joinstrRefresh),
          ),
        ),
        Expanded(
          child: state.status == JoinstrStatus.loadingPools
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const Gap(12),
                      Text(context.loc.joinstrConnectingTor),
                    ],
                  ),
                )
              : state.pools.isEmpty
              ? _EmptyState(message: context.loc.joinstrNoActivePools)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.pools.length,
                  separatorBuilder: (_, _) => const Gap(12),
                  itemBuilder: (context, index) => _PoolCard(
                    pool: state.pools[index],
                    enabled: state.canInteract,
                  ),
                ),
        ),
      ],
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool, required this.enabled});

  final JoinstrPool pool;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.joinstrDenominationLine(
                Joinstr.formatBtc(pool.denominationSat),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Gap(4),
            Text(loc.joinstrPeersLine(pool.peers)),
            Text(loc.joinstrFeeRateLine(pool.feeRateSatPerVb)),
            Text(
              loc.joinstrRelayLine(pool.relay),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            _CountdownText(expiresAtUnixSec: pool.expiresAtUnixSec),
            const Gap(8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled ? () => _confirmJoin(context, pool) : null,
                child: Text(loc.joinstrJoin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Matches the references: joining is confirmed against the initiator's
  /// nostr public key, the only identity a pool announcement carries.
  void _confirmJoin(BuildContext context, JoinstrPool pool) {
    final cubit = context.read<JoinstrCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.loc.joinstrJoin),
        content: Text(dialogContext.loc.joinstrPublicKeyLine(pool.publicKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.loc.joinstrCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.joinPool(pool);
            },
            child: Text(dialogContext.loc.joinstrContinue),
          ),
        ],
      ),
    );
  }
}

/// Ticks once a second while the pool is live, like the countdowns in
/// joinstr-kmp and floresta_wallet.
class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.expiresAtUnixSec});

  final int expiresAtUnixSec;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
    final remaining =
        widget.expiresAtUnixSec - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final text = remaining > 0
        ? context.loc.joinstrTimeRemaining(Joinstr.formatRemaining(remaining))
        : context.loc.joinstrExpired;
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});

  final List<JoinstrHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _EmptyState(message: context.loc.joinstrNoHistory);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (_, _) => const Gap(12),
      itemBuilder: (context, index) {
        final entry = history[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.loc.joinstrAmountLine(
                    Joinstr.formatBtc(entry.amountSat),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Gap(4),
                Text(
                  context.loc.joinstrTxLine(entry.txId),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  context.loc.joinstrRelayLine(entry.relay),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String joinstrErrorMessage(BuildContext context, JoinstrException error) {
  return switch (error.issue) {
    JoinstrIssue.bitcoinOnly => context.loc.joinstrErrorBitcoinOnly,
    JoinstrIssue.mainnetNotSupported => context.loc.joinstrErrorMainnet,
    JoinstrIssue.watchOnlyWallet => context.loc.joinstrErrorWatchOnly,
    JoinstrIssue.unsupportedScriptType => context.loc.joinstrErrorScriptType,
    JoinstrIssue.noEligibleCoin => context.loc.joinstrErrorNoEligibleCoin(
      (error.denominationSat ?? 0) + Joinstr.minInputSurplusSat,
      (error.denominationSat ?? 0) + Joinstr.maxInputSurplusSat,
      Joinstr.scanDepth,
    ),
    JoinstrIssue.invalidElectrumUrl => context.loc.joinstrErrorElectrum,
    JoinstrIssue.invalidPoolConfig => context.loc.joinstrErrorPoolConfig,
    JoinstrIssue.invalidRelayUrl => context.loc.joinstrErrorRelay,
    JoinstrIssue.torUnavailable => context.loc.joinstrErrorTor,
    JoinstrIssue.poolNotFound => context.loc.joinstrErrorPoolNotFound,
    JoinstrIssue.coinjoinFailed => context.loc.joinstrErrorFailed(
      error.detail ?? '',
    ),
  };
}
