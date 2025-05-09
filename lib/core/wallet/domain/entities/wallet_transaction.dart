import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';

enum WalletTransactionDirection { incoming, outgoing }

enum WalletTransactionStatus {
  pending,
  confirmed;

  String get displayName {
    switch (this) {
      case WalletTransactionStatus.pending:
        return 'Pending';
      case WalletTransactionStatus.confirmed:
        return 'Confirmed';
    }
  }
}

@freezed
sealed class WalletTransaction with _$WalletTransaction implements Labelable {
  const factory WalletTransaction.bitcoin({
    required String walletId,
    required WalletTransactionDirection direction,
    required WalletTransactionStatus status,
    required String txId,
    required int amountSat,
    required int feeSat,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    DateTime? confirmationTime,
    @Default(false) bool isToSelf,
    @Default([]) List<String> labels,
    Payjoin? payjoin,
    Swap? swap,
    @Default('') String exchangeId,
  }) = BitcoinWalletTransaction;
  const factory WalletTransaction.liquid({
    required String walletId,
    required WalletTransactionDirection direction,
    required WalletTransactionStatus status,
    required String txId,
    required int amountSat,
    required int feeSat,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    DateTime? confirmationTime,
    @Default(false) bool isToSelf,
    @Default([]) List<String> labels,
    Swap? swap,
    @Default('') String exchangeId,
  }) = LiquidWalletTransaction;
  const WalletTransaction._();

  bool get isIncoming => direction == WalletTransactionDirection.incoming;
  bool get isOutgoing => direction == WalletTransactionDirection.outgoing;
  bool get isPending => status == WalletTransactionStatus.pending;
  bool get isConfirmed => status == WalletTransactionStatus.confirmed;
  bool get isPayjoin =>
      this is BitcoinWalletTransaction &&
      (this as BitcoinWalletTransaction).payjoin != null;
  bool get isSwap => swap != null;
  bool get isLnSwap => isSwap && (swap!.isLnReceiveSwap || swap!.isLnSendSwap);
  bool get isChainSwap => isSwap && swap!.isChainSwap;
  bool get isExchange => exchangeId.isNotEmpty;

  TransactionOutput get destinationOutput {
    if (isToSelf) {
      return outputs.first;
    } else if (direction == WalletTransactionDirection.incoming) {
      return outputs.firstWhere((output) => output.isOwn);
    } else {
      return outputs.firstWhere((output) => !output.isOwn);
    }
  }

  String get toAddress {
    final output = destinationOutput;

    switch (output) {
      case BitcoinTransactionOutput _:
        return output.address;
      case LiquidTransactionOutput _:
        return output.confidentialAddress;
    }
  }

  List<String> get toAddressLabels {
    final output = destinationOutput;
    return output.addressLabels;
  }

  @override
  String get labelRef => txId;
}
