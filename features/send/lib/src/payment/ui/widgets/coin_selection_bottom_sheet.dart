import 'package:address_view/address_view.dart';
import 'package:send/src/payment/domain/send_failure.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/send_localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:coins/coins.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:label_editor/label_editor.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show Keychain;

bool selectionFailureShowsWarning(SendFailure? failure) {
  return failure is SendInsufficientBalanceFailure ||
      failure is SendInsufficientFundsForFeesFailure ||
      failure is SendSelectedCoinsInsufficientFailure ||
      failure is SendSelectedCoinsUnavailableFailure;
}

class CoinSelectionBottomSheet extends StatelessWidget {
  const CoinSelectionBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bitcoinUnit = context.select(
      (SendCubit send) => send.state.bitcoinUnit,
    );
    if (bitcoinUnit == null) return const SizedBox.shrink();
    final exchangeRate = context.select(
      (SendCubit send) => send.state.exchangeRate,
    );
    final fiatCurrency = context.select(
      (SendCubit send) => send.state.fiatCurrencyCode,
    );
    final utxos = context
        .select((SendCubit send) => send.state.utxos)
        .where((coin) => !coin.isFrozen)
        .toList();
    final selectedUtxos = context.select(
      (SendCubit send) => send.state.selectedUtxos,
    );
    final requestedAmount = context.select(
      (SendCubit send) => send.state.confirmedAmountSat ?? 0,
    );
    final building = context.select(
      (SendCubit send) => send.state.buildingTransaction,
    );
    final hasBuiltFee = context.select(
      (SendCubit send) => send.state.absoluteFees != null,
    );
    final selectionIsShort = context.select(
      (SendCubit send) => selectionFailureShowsWarning(send.state.failure),
    );
    final selectable = {for (final coin in utxos) coin.outpoint: coin};
    final labels = context.loc;

    return CoinSelectionSheet(
      bitcoinUnit: bitcoinUnit,
      exchangeRate: exchangeRate,
      fiatCurrency: fiatCurrency,
      coins: [
        for (final coin in selectable.values)
          (
            outpoint: coin.outpoint,
            amount: Sats(coin.amountSat),
            address: coin.address,
            addressType: coin.addressKeyChain == Keychain.external
                ? labels.sendReceive
                : labels.sendChange,
          ),
      ],
      initialSelection: {for (final coin in selectedUtxos) coin.outpoint},
      requestedAmount: Sats.fromInt(requestedAmount),
      labels: (
        title: labels.sendSelectAmount,
        close: labels.closeDialogButton,
        requested: (amount) => '${labels.sendAmountRequested}$amount',
        insufficient: labels.sendSelectedUtxosInsufficient,
        address: labels.sendAddress,
        type: labels.sendType,
        done: labels.sendDone,
      ),
      addressBuilder: (address, style, color) =>
          AddressViewer(address, style: style, color: color),
      onToggle: (outpoint) {
        final coin = selectable[outpoint];
        if (coin != null) context.read<SendCubit>().utxoSelected(coin);
      },
      doneEnabled:
          (selectedUtxos.isEmpty || (!building && hasBuiltFee)) &&
          !selectionIsShort,
      showInsufficient: selectionIsShort,
      showAddressType: (entry) =>
          selectable[entry.outpoint] is BitcoinWalletUtxo,
      statusBuilder: (entry) {
        final coin = selectable[entry.outpoint];
        if (coin == null) return null;
        final status = !coin.isConfirmed
            ? labels.sendUnconfirmed
            : coin is LiquidWalletUtxo
            ? labels.coreWalletTransactionStatusConfirmed
            : labels.sendCoinConfirmations(coin.confirmations);
        return BullText(status, style: context.bullType.caption);
      },
      labelsBuilder: (entry) {
        final coin = selectable[entry.outpoint];
        if (coin == null) return null;
        return LabelsWidget(
          labels: [...coin.labels, ...coin.addressLabels, ...coin.txLabels],
        );
      },
      onDone: (_) {},
    );
  }
}
