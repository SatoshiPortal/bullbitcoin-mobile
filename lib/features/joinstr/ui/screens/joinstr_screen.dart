import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_cubit.dart';
import 'package:bb_mobile/features/joinstr/presentation/joinstr_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class JoinstrScreen extends StatelessWidget {
  const JoinstrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.joinstrTitle),
        actions: [
          BlocBuilder<JoinstrCubit, JoinstrState>(
            buildWhen: (a, b) => a.canInteract != b.canInteract,
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: state.canInteract
                  ? () => context.read<JoinstrCubit>().refreshPools()
                  : null,
            ),
          ),
        ],
      ),
      body: BlocBuilder<JoinstrCubit, JoinstrState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _JoinstrNotice(),
              const Gap(16),
              if (state.error != null) ...[
                _JoinstrError(error: state.error!),
                const Gap(16),
              ],
              if (state.txId != null) ...[
                _JoinstrSuccess(txId: state.txId!),
                const Gap(16),
              ],
              if (state.isRunning) ...[const _JoinstrRunning(), const Gap(16)],
              Text(
                context.loc.joinstrAvailablePools,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              if (state.status == JoinstrStatus.loadingPools)
                const Center(child: CircularProgressIndicator())
              else if (state.pools.isEmpty)
                Text(context.loc.joinstrNoPools)
              else
                for (final pool in state.pools)
                  _PoolTile(pool: pool, enabled: state.canInteract),
              const Gap(24),
              const Divider(),
              const Gap(8),
              Text(
                context.loc.joinstrCreatePool,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Gap(8),
              const _CreatePoolForm(),
            ],
          );
        },
      ),
    );
  }
}

/// Joinstr traffic is not routed over Tor yet, so the relay and the electrum
/// server both see the joining IP next to the outpoint being mixed. The
/// feature is therefore testnet-only for now.
class _JoinstrNotice extends StatelessWidget {
  const _JoinstrNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.science_outlined),
            const Gap(12),
            Expanded(child: Text(context.loc.joinstrExperimentalNotice)),
          ],
        ),
      ),
    );
  }
}

class _JoinstrRunning extends StatelessWidget {
  const _JoinstrRunning();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        const Gap(8),
        Text(context.loc.joinstrRunning, textAlign: TextAlign.center),
      ],
    );
  }
}

class _JoinstrSuccess extends StatelessWidget {
  const _JoinstrSuccess({required this.txId});

  final String txId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline),
        title: Text(context.loc.joinstrBroadcast),
        subtitle: Text(txId),
      ),
    );
  }
}

class _JoinstrError extends StatelessWidget {
  const _JoinstrError({required this.error});

  final JoinstrException error;

  @override
  Widget build(BuildContext context) {
    return Text(
      joinstrErrorMessage(context, error),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _PoolTile extends StatelessWidget {
  const _PoolTile({required this.pool, required this.enabled});

  final JoinstrPool pool;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          context.loc.joinstrPoolSummary(pool.denominationSat, pool.peers),
        ),
        subtitle: Text(
          context.loc.joinstrPoolDetail(
            pool.feeRateSatPerVb,
            pool.secondsUntilExpiry(DateTime.now()),
          ),
        ),
        trailing: FilledButton(
          onPressed: enabled
              ? () => context.read<JoinstrCubit>().joinPool(pool)
              : null,
          child: Text(context.loc.joinstrJoin),
        ),
      ),
    );
  }
}

class _CreatePoolForm extends StatelessWidget {
  const _CreatePoolForm();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<JoinstrCubit>();
    final state = context.watch<JoinstrCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: state.denominationSat,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.loc.joinstrDenomination,
          ),
          onChanged: cubit.denominationChanged,
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: state.peers,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.loc.joinstrPeers,
                ),
                onChanged: cubit.peersChanged,
              ),
            ),
            const Gap(16),
            Expanded(
              child: TextFormField(
                initialValue: state.feeRate,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.loc.joinstrFeeRate,
                ),
                onChanged: cubit.feeRateChanged,
              ),
            ),
          ],
        ),
        const Gap(12),
        FilledButton(
          onPressed: state.canInteract ? cubit.initiatePool : null,
          child: Text(context.loc.joinstrCreatePool),
        ),
      ],
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
    ),
    JoinstrIssue.invalidElectrumUrl => context.loc.joinstrErrorElectrum,
    JoinstrIssue.invalidPoolConfig => context.loc.joinstrErrorPoolConfig,
    JoinstrIssue.poolNotFound => context.loc.joinstrErrorPoolNotFound,
    JoinstrIssue.coinjoinFailed => context.loc.joinstrErrorFailed(
      error.detail ?? '',
    ),
  };
}
