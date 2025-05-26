import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_view_model.freezed.dart';

@freezed
sealed class TransactionViewModel with _$TransactionViewModel {
  const factory TransactionViewModel({
    WalletTransaction? walletTransaction,
    Swap? swap,
    Payjoin? payjoin,
    Wallet? fromWallet,
    Wallet? toWallet,
    String? description,
  }) = _TransactionViewModel;

  const TransactionViewModel._();

  String get txId =>
      walletTransaction?.txId ?? payjoin?.txId ?? payjoin?.originalTxId ?? '';
  int get amountSat => walletTransaction?.amountSat ?? payjoin?.amountSat ?? 0;
  DateTime? get timestamp =>
      payjoin?.createdAt ??
      swap?.creationTime ??
      walletTransaction?.confirmationTime;
  bool get isBitcoin =>
      walletTransaction != null && walletTransaction!.isBitcoin ||
      isPayjoin ||
      swap?.type == SwapType.bitcoinToLiquid;
  bool get isTestnet => fromWallet?.isTestnet ?? toWallet?.isTestnet ?? false;
  bool get isLightning => [
    SwapType.lightningToBitcoin,
    SwapType.lightningToLiquid,
    SwapType.liquidToLightning,
    SwapType.bitcoinToLightning,
  ].contains(swap?.type);
  Wallet? get wallet =>
      isIncoming
          ? toWallet
          : isOutgoing
          ? fromWallet
          : toWallet ?? fromWallet;
  bool get isIncoming => toWallet != null && fromWallet == null;
  bool get isOutgoing => fromWallet != null && toWallet == null;
  bool get isToSameWallet =>
      toWallet != null && fromWallet != null && toWallet!.id == fromWallet!.id;
  bool get isBetweenWallets =>
      toWallet != null && fromWallet != null && toWallet!.id != fromWallet!.id;

  bool get isSwap => swap != null;
  bool get isPayjoin => payjoin != null;
  bool get isLnSwap => isSwap && (swap!.isLnReceiveSwap || swap!.isLnSendSwap);
  bool get isChainSwap => isSwap && swap!.isChainSwap;
}
