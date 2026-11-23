import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, BitcoinUnit;
import 'package:primitives/primitives.dart' show Network, NetworkEnv;

import '../../swap_l10n.dart';

import 'package:swap_feature/src/domain/entities/internal_transfer.dart';
import 'package:swap_feature/src/presentation/internal_ark_transfer_cubit.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/ui/widgets/internal_transfer_form.dart';

import 'swap_page.dart';

class InternalTransferPage extends StatefulWidget {
  final InternalArkTransferCubit Function() createArkCubit;

  const InternalTransferPage({super.key, required this.createArkCubit});
  @override
  State<InternalTransferPage> createState() => _InternalTransferPageState();
}

class _InternalTransferPageState extends State<InternalTransferPage> {
  late final InternalArkTransferCubit _ark;
  bool _legacy = false;

  @override
  void initState() {
    super.initState();
    _ark = widget.createArkCubit()..load();
  }

  @override
  void dispose() {
    _ark.close();
    super.dispose();
  }

  BitcoinNetwork _network(Network network) => switch (network.env) {
    NetworkEnv.regtest => BitcoinNetwork.regtest,
    NetworkEnv.testnet => BitcoinNetwork.testnet,
    NetworkEnv.mainnet => BitcoinNetwork.mainnet,
    NetworkEnv.signet => BitcoinNetwork.signet,
  };

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<InternalArkTransferCubit, InternalArkTransferState>(
    bloc: _ark,
    listener: (context, state) async {
      final handoff = state.handoff;
      if (handoff == null) return;
      await context.push(handoff.path, extra: handoff.entry);
      if (mounted) _ark.returned();
    },
    builder: (context, arkState) {
      final ark = arkState.context;
      if (_legacy || (ark == null && !arkState.busy)) return const SwapPage();
      if (ark == null) {
        return const BullScaffold(body: Center(child: BullShimmerLine()));
      }
      return BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          if (state.isStarting) {
            return const BullScaffold(body: Center(child: BullShimmerLine()));
          }
          return InternalTransferForm(
            wallets: [
              for (final wallet in state.wallets)
                TransferWallet(
                  id: wallet.id,
                  label: wallet.swapWalletLabel(context),
                  kind: wallet.isLiquid
                      ? TransferWalletKind.liquid
                      : TransferWalletKind.bitcoin,
                  network: _network(wallet.network),
                  balance: wallet.balanceSat,
                  canSend: wallet.signsLocally,
                ),
            ],
            ark: ark,
            busy: arkState.busy,
            failure: arkState.failure,
            onEdit: _ark.edit,
            onExternal: () {
              context.read<TransferBloc>().add(
                const TransferEvent.sendToExternalToggled(true),
              );
              setState(() => _legacy = true);
            },
            onContinue: (transfer) {
              if (transfer.usesArk) {
                _ark.review(transfer);
                return;
              }
              final from = state.wallets
                  .where((w) => w.id == transfer.from.id)
                  .firstOrNull;
              final to = state.wallets
                  .where((w) => w.id == transfer.to.id)
                  .firstOrNull;
              if (from == null || to == null) return;
              final bloc = context.read<TransferBloc>();
              bloc.add(
                TransferEvent.walletsChanged(fromWallet: from, toWallet: to),
              );
              final amount = transfer.amount;
              if (amount == null) return;
              bloc.add(
                TransferEvent.amountChanged(
                  state.bitcoinUnit == BitcoinUnit.sats
                      ? amount.toString()
                      : (amount.toDouble() / 100000000).toStringAsFixed(8),
                ),
              );
              setState(() => _legacy = true);
            },
          );
        },
      );
    },
  );
}
