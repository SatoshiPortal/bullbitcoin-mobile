import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bitcoin_descriptor_backup.dart';
import 'package:bb_mobile/features/bullvault/presentation/bitcoin_backup_cubit.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';

class BitcoinBackupPrototypeScreen extends StatefulWidget {
  final String initialEndpoint;
  final BitcoinBackupNetwork initialNetwork;
  final VoidCallback onOpenNostr;
  const BitcoinBackupPrototypeScreen({
    super.key,
    required this.initialEndpoint,
    required this.initialNetwork,
    required this.onOpenNostr,
  });

  @override
  State<BitcoinBackupPrototypeScreen> createState() =>
      _BitcoinBackupPrototypeScreenState();
}

class _BitcoinBackupPrototypeScreenState
    extends State<BitcoinBackupPrototypeScreen>
    with PrivacyScreen, WidgetsBindingObserver {
  var _input = '';
  late var _endpoint = widget.initialEndpoint;
  late var _network = widget.initialNetwork;

  ElectrumConnection get _connection => ElectrumConnection(
    url: _endpoint.trim(),
    retry: 0,
    timeout: 15,
    stopGap: 20,
    validateDomain: true,
    isCustom: true,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<BitcoinBackupCubit>().cancel(preserveCandidates: true);
    }
  }

  @override
  Widget build(BuildContext context) => BullScaffold(
    body: SafeArea(
      child: BlocBuilder<BitcoinBackupCubit, BitcoinBackupState>(
        builder: (context, state) {
          final cubit = context.read<BitcoinBackupCubit>();
          final result = state.result;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.loc.distributedBackupTitle),
                const Gap(12),
                Text(context.loc.distributedBackupNotice),
                const Gap(12),
                BullButton.small(
                  label: context.loc.distributedBackupNostr,
                  bgColor: context.bull.surface,
                  textColor: context.bull.text,
                  disabled: state.busy,
                  onPressed: () {
                    cubit.cancel();
                    widget.onOpenNostr();
                  },
                ),
                const Gap(12),
                Text(context.loc.distributedBackupNetwork),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final network in BitcoinBackupNetwork.values)
                      BullButton.small(
                        label: network.name,
                        bgColor: network == _network
                            ? context.bull.primary
                            : context.bull.surface,
                        textColor: network == _network
                            ? context.bull.onPrimary
                            : context.bull.text,
                        disabled: state.busy,
                        onPressed: () {
                          cubit.cancel();
                          setState(() => _network = network);
                        },
                      ),
                  ],
                ),
                const Gap(12),
                BullPasteInput(
                  key: const ValueKey('bitcoin-electrum-input'),
                  text: _endpoint,
                  enabled: !state.busy,
                  hint: context.loc.distributedBackupElectrum,
                  onChanged: (value) {
                    cubit.cancel();
                    setState(() => _endpoint = value);
                  },
                ),
                const Gap(12),
                BullPasteInput(
                  key: const ValueKey('bitcoin-xpub-input'),
                  text: _input,
                  enabled: !state.busy,
                  hint: context.loc.bip138PrototypeInput,
                  onChanged: (value) {
                    cubit.cancel();
                    setState(() => _input = value);
                  },
                ),
                const Gap(12),
                BullButton.big(
                  key: const ValueKey('fetch-bitcoin-backup'),
                  label: context.loc.bip138PrototypeFetch,
                  bgColor: context.bull.primary,
                  textColor: context.bull.onPrimary,
                  disabled: state.busy || _input.trim().isEmpty,
                  onPressed: () => cubit.fetch(_input, _network, _connection),
                ),
                if (state.busy) ...[
                  const Gap(12),
                  Text(context.loc.distributedBackupWorking),
                  BullButton.small(
                    label: context.loc.cancelButton,
                    bgColor: context.bull.surface,
                    textColor: context.bull.text,
                    onPressed: () => cubit.cancel(preserveCandidates: true),
                  ),
                ],
                if (state.failure case final failure?)
                  Text(failure.toTranslated(context)),
                if (result != null) ...[
                  const Gap(12),
                  Text(result.discoveryAddress),
                  if (result.incomplete)
                    Text(context.loc.distributedBackupIncomplete),
                  if (result.candidates.isEmpty && !result.incomplete)
                    Text(context.loc.distributedBackupEmpty),
                  for (var i = 0; i < result.candidates.length; i++) ...[
                    const Gap(24),
                    Text(
                      result.candidates[i].txid,
                      key: ValueKey('bitcoin-txid-$i'),
                    ),
                    Text(
                      context.loc.distributedBackupHeight(
                        result.candidates[i].reportedHeight,
                      ),
                    ),
                    Text(
                      result.candidates[i].descriptor,
                      key: ValueKey('bitcoin-descriptor-$i'),
                    ),
                    Text(context.loc.distributedBackupUnverified),
                    const Gap(12),
                    BullButton.big(
                      key: ValueKey('restore-bitcoin-backup-$i'),
                      label: context.loc.distributedBackupRestore,
                      bgColor: context.bull.primary,
                      textColor: context.bull.onPrimary,
                      disabled: state.busy,
                      onPressed: () => cubit.restore(
                        result.candidates[i],
                        _network,
                        _connection,
                      ),
                    ),
                  ],
                ],
                if (state.restored case final wallet?) ...[
                  const Gap(24),
                  Text(
                    context.loc.distributedBackupRestored,
                    key: const ValueKey('bitcoin-restored'),
                  ),
                  Text(
                    context.loc.distributedBackupBalance(
                      wallet.balanceSats,
                      wallet.transactionCount,
                    ),
                  ),
                  Text(
                    context.loc.distributedBackupAddresses(
                      wallet.receiveAddress,
                      wallet.changeAddress,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
