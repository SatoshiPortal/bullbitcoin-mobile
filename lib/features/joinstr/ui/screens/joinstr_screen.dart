import 'dart:async';

import 'package:bb_mobile/core/utils/amount_conversions.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_coin.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_history_entry.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr_round.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

/// Tabs, labels, the input picker and the coinjoin timeline mirror joinstr-kmp
/// and floresta_wallet: Create New Pool, My Pools, View Other Pools, History.
class JoinstrScreen extends StatefulWidget {
  const JoinstrScreen({super.key});

  @override
  State<JoinstrScreen> createState() => _JoinstrScreenState();
}

class _JoinstrScreenState extends State<JoinstrScreen> {
  int _seenRounds = 0;
  JoinstrException? _seenError;

  @override
  void initState() {
    super.initState();
    // The cubit is a singleton that outlives the screen: seed from its
    // current state so re-entering does not misread existing rounds as new
    // (spurious created-snackbar and tab jump) or an old error as fresh.
    final state = context.read<JoinstrCubit>().state;
    _seenRounds = state.rounds.length;
    _seenError = state.error;
  }

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
              prev.error != curr.error,
          listener: _onStateChange,
          builder: (context, state) {
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

  void _onStateChange(BuildContext context, JoinstrState state) {
    if (state.rounds.length > _seenRounds && state.rounds.isNotEmpty) {
      final top = state.rounds.first;
      SnackBarUtils.showSnackBar(
        context,
        top.initiated
            ? context.loc.joinstrPoolCreatedSnack
            : context.loc.joinstrJoinRequestSnack,
      );
      DefaultTabController.of(context).animateTo(1); // My Pools
    } else if (state.wallet != null &&
        state.error != null &&
        state.error != _seenError) {
      SnackBarUtils.showSnackBar(
        context,
        joinstrErrorMessage(context, state.error!),
      );
    }
    _seenRounds = state.rounds.length;
    _seenError = state.error;
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
    ).whenComplete(controller.dispose);
  }
}

class _CreatePoolTab extends StatelessWidget {
  const _CreatePoolTab({required this.state});

  final JoinstrState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JoinstrCubit>();
    final feeRate = int.tryParse(state.feeRate) ?? 0;
    final coin = state.selectedCoin;
    final denomination = coin == null || feeRate <= 0
        ? null
        : Joinstr.deriveDenominationSat(
            coinValueSat: coin.valueSat,
            feeRateSatPerVb: feeRate,
          );
    final ready =
        coin != null &&
        (int.tryParse(state.peers) ?? 0) >= 2 &&
        feeRate > 0 &&
        denomination != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Coin first: the denomination is derived from whichever input the
        // user picks, so there is nothing to type and no ineligible-coin trap.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.loc.joinstrSelectInput,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.loc.joinstrRefreshCoins,
              onPressed: state.loadingCoins ? null : cubit.loadCoins,
            ),
          ],
        ),
        const Gap(4),
        _CreateInputPicker(
          state: state,
          selected: coin,
          onSelect: cubit.selectCoin,
        ),
        const Gap(16),
        _NumberField(
          value: state.peers,
          label: context.loc.joinstrPeers,
          onChanged: cubit.peersChanged,
        ),
        const Gap(12),
        _NumberField(
          value: state.feeRate,
          label: context.loc.joinstrFeeRate,
          onChanged: cubit.feeRateChanged,
        ),
        if (denomination != null) ...[
          const Gap(12),
          Text(
            context.loc.joinstrDenominationLine(_btc(denomination)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        const Gap(16),
        FilledButton(
          onPressed: ready ? cubit.initiatePool : null,
          child: Text(context.loc.joinstrCreate),
        ),
      ],
    );
  }
}

/// The coin picker for creating a pool: every spendable coin large enough to
/// form a pool. Whichever the user taps sets the denomination.
class _CreateInputPicker extends StatelessWidget {
  const _CreateInputPicker({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final JoinstrState state;
  final JoinstrCoin? selected;
  final ValueChanged<JoinstrCoin?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (state.loadingCoins) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const Gap(12),
            Text(context.loc.joinstrLoadingCoins),
          ],
        ),
      );
    }
    final coins = state.createCoins;
    if (coins.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(context.loc.joinstrNoSpendableCoins),
      );
    }
    return Column(
      children: [
        for (final coin in coins)
          _CoinTile(
            coin: coin,
            selected: coin.outpoint == selected?.outpoint,
            onTap: () => onSelect(coin),
          ),
      ],
    );
  }
}

class _CoinTile extends StatelessWidget {
  const _CoinTile({
    required this.coin,
    required this.selected,
    required this.onTap,
  });

  final JoinstrCoin coin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
        ),
        title: Text(
          _btc(coin.valueSat),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${coin.txid.substring(0, 16)}…:${coin.vout}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Labelled numeric input on top of the app-wide [BBInputText].
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const Gap(4),
        BBInputText(value: value, onChanged: onChanged, onlyNumbers: true),
      ],
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

/// A compact My Pools row. Tapping it opens the round's coinjoin timeline.
class _RoundCard extends StatelessWidget {
  const _RoundCard({required this.round});

  final JoinstrRound round;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final Widget trailing;
    if (round.isBroadcast) {
      trailing = Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
      );
    } else if (round.isFailed) {
      trailing = Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      );
    } else {
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Card(
      child: ListTile(
        title: Text(
          loc.joinstrDenominationLine(_btc(round.denominationSat)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          round.isWaiting
              ? _stepLabel(context, round.step, initiated: round.initiated)
              : round.isBroadcast
              ? loc.joinstrBroadcast
              : joinstrErrorMessage(context, round.error!),
        ),
        trailing: trailing,
        onTap: () {
          final cubit = context.read<JoinstrCubit>();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: _RoundTimelineScreen(roundId: round.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen coinjoin timeline for one round, rebuilt live from the cubit so
/// the steps advance while it is open.
class _RoundTimelineScreen extends StatelessWidget {
  const _RoundTimelineScreen({required this.roundId});

  final int roundId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JoinstrCubit, JoinstrState>(
      builder: (context, state) {
        final matches = state.rounds.where((r) => r.id == roundId).toList();
        final round = matches.isEmpty ? null : matches.first;
        return Scaffold(
          appBar: AppBar(title: Text(context.loc.joinstrTitle)),
          body: round == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_RoundDetail(round: round)],
                ),
        );
      },
    );
  }
}

class _RoundDetail extends StatelessWidget {
  const _RoundDetail({required this.round});

  final JoinstrRound round;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.joinstrDenominationLine(_btc(round.denominationSat)),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const Gap(4),
        Text(loc.joinstrPeersLine(round.peers)),
        Text(
          loc.joinstrInputLine(round.inputOutpoint),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          loc.joinstrRelayLine(round.relay),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (round.isWaiting) ...[
          const Gap(4),
          _CountdownText(expiresAtUnixSec: round.expiresAtUnixSec),
        ],
        const Gap(16),
        _CoinjoinTimeline(round: round),
        if (round.isBroadcast) ...[
          const Gap(12),
          SelectableText(
            '${loc.joinstrBroadcast}: ${round.txId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (round.isFailed) ...[
          const Gap(12),
          Text(
            joinstrErrorMessage(context, round.error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

/// The coinjoin progress timeline from the reference wallets: each step is
/// checked off as the round advances, the current one spins, later ones wait.
class _CoinjoinTimeline extends StatelessWidget {
  const _CoinjoinTimeline({required this.round});

  final JoinstrRound round;

  @override
  Widget build(BuildContext context) {
    const steps = JoinstrRoundStep.timeline;
    final currentIndex = round.isBroadcast
        ? steps
              .length // every step done
        : steps.indexOf(round.step).clamp(0, steps.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed)
          _TimelineRow(
            label: _stepLabel(context, step, initiated: round.initiated),
            description: i <= currentIndex
                ? _stepDescription(context, step, round)
                : null,
            done: i < currentIndex,
            current: i == currentIndex && !round.isBroadcast && !round.isFailed,
            failed: round.isFailed && i == currentIndex,
            last: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.description,
    required this.done,
    required this.current,
    required this.failed,
    required this.last,
  });

  final String label;
  final String? description;
  final bool done;
  final bool current;
  final bool failed;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reached = done || current || failed;
    final Widget marker;
    if (failed) {
      marker = Icon(Icons.error_outline, size: 18, color: scheme.error);
    } else if (done) {
      marker = Icon(Icons.check_circle, size: 18, color: scheme.primary);
    } else if (current) {
      marker = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      marker = Icon(
        Icons.radio_button_unchecked,
        size: 18,
        color: scheme.outlineVariant,
      );
    }
    // A marker column with the connecting line drawn between markers, so the
    // rows read as one continuous vertical timeline like the reference wallets.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox(width: 18, height: 24, child: Center(child: marker)),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const Gap(12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: current ? FontWeight.bold : FontWeight.w500,
                        color: reached ? null : scheme.outline,
                      ),
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const Gap(2),
                    Text(
                      description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _stepLabel(
  BuildContext context,
  JoinstrRoundStep step, {
  bool initiated = true,
}) => switch (step) {
      // `connecting` is transient plumbing we never surface as a status; a fresh
      // round shows the first real step instead of "Connecting". Posting only
      // happens for the creator (a joiner skips to registration), so name the
      // first row for what the joiner actually did.
      JoinstrRoundStep.connecting || JoinstrRoundStep.posting => initiated
          ? context.loc.joinstrStepPosting
          : context.loc.joinstrStepJoinPool,
      JoinstrRoundStep.outputRegistration =>
        context.loc.joinstrStepOutputRegistration,
      JoinstrRoundStep.inputRegistration =>
        context.loc.joinstrStepInputRegistration,
      JoinstrRoundStep.broadcast => context.loc.joinstrStepBroadcast,
      JoinstrRoundStep.mined => context.loc.joinstrStepMined,
      JoinstrRoundStep.done ||
      JoinstrRoundStep.failed ||
      JoinstrRoundStep.other => '',
    };

/// The line under each timeline step, mirroring the reference wallets: a short
/// status, carrying the real input outpoint and broadcast txid where we have
/// them.
String _stepDescription(
  BuildContext context,
  JoinstrRoundStep step,
  JoinstrRound round,
) => switch (step) {
  JoinstrRoundStep.posting => round.initiated
      ? context.loc.joinstrStepPostingDesc
      : context.loc.joinstrStepJoinPoolDesc,
  JoinstrRoundStep.outputRegistration =>
    context.loc.joinstrStepOutputRegistrationDesc,
  JoinstrRoundStep.inputRegistration => context.loc
      .joinstrStepInputRegistrationDesc(round.inputOutpoint),
  JoinstrRoundStep.broadcast => context.loc.joinstrStepBroadcastDesc,
  JoinstrRoundStep.mined => round.txId != null
      ? context.loc.joinstrStepMinedDesc(round.txId!)
      : '',
  JoinstrRoundStep.connecting ||
  JoinstrRoundStep.done ||
  JoinstrRoundStep.failed ||
  JoinstrRoundStep.other => '',
};

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
                  itemBuilder: (context, index) =>
                      _PoolCard(pool: state.pools[index], state: state),
                ),
        ),
      ],
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool, required this.state});

  final JoinstrPool pool;
  final JoinstrState state;

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
              loc.joinstrDenominationLine(_btc(pool.denominationSat)),
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
                onPressed: state.canInteract
                    ? () => _pickInputAndJoin(context, pool)
                    : null,
                child: Text(loc.joinstrJoin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Joining also needs a user-chosen input coin, so present the same picker
  /// filtered to this pool's denomination before starting the join.
  void _pickInputAndJoin(BuildContext context, JoinstrPool pool) {
    final cubit = context.read<JoinstrCubit>();
    final coins = state.eligibleCoins(pool.denominationSat);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.loc.joinstrPublicKeyLine(pool.publicKey),
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const Gap(12),
              Text(
                sheetContext.loc.joinstrSelectInput,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const Gap(8),
              if (coins.isEmpty)
                Text(sheetContext.loc.joinstrNoEligibleCoins)
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final coin in coins)
                          _CoinTile(
                            coin: coin,
                            selected: false,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              cubit.joinPool(pool, coin);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                  context.loc.joinstrAmountLine(_btc(entry.amountSat)),
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

String _btc(int sat) => FormatAmount.btc(ConvertAmount.satsToBtc(sat));

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
    JoinstrIssue.coinUnavailable => context.loc.joinstrErrorCoinUnavailable,
    JoinstrIssue.invalidElectrumUrl => context.loc.joinstrErrorElectrum,
    JoinstrIssue.invalidPoolConfig => context.loc.joinstrErrorPoolConfig,
    JoinstrIssue.invalidRelayUrl => context.loc.joinstrErrorRelay,
    JoinstrIssue.torUnavailable => context.loc.joinstrErrorTor,
    JoinstrIssue.coinjoinFailed => context.loc.joinstrErrorFailed(
      error.detail ?? '',
    ),
  };
}
