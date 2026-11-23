import 'package:transactions/src/domain/entities/transaction_input.dart';
import 'package:transactions/src/domain/entities/transaction_output.dart';
import 'package:primitives/primitives.dart';
import 'package:labels/labels.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';

enum WalletTransactionDirection { incoming, outgoing }

enum WalletTransactionStatus { pending, confirmed }

@freezed
sealed class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String walletId,
    required Network network,
    required WalletTransactionDirection direction,
    required WalletTransactionStatus status,
    required String txId,
    required int amountSat,
    required int feeSat,
    required int vsize,
    required List<TransactionInput> inputs,
    required List<TransactionOutput> outputs,
    required bool isRbf,
    DateTime? confirmationTime,
    @Default(false) bool isToSelf,
    @Default([]) List<Label> labels,
    String? unblindedUrl,
  }) = _WalletTransaction;

  const WalletTransaction._();

  bool get isBitcoin => network is BitcoinNetwork;
  bool get isLiquid => network is LiquidNetwork;
  bool get isMainnet => network.isMainnet;
  bool get isIncoming => direction == WalletTransactionDirection.incoming;
  bool get isOutgoing => direction == WalletTransactionDirection.outgoing;
  bool get isPending => status == WalletTransactionStatus.pending;
  bool get isConfirmed => status == WalletTransactionStatus.confirmed;

  TransactionOutput? get destinationOutput {
    if (outputs.isEmpty) {
      return null;
    }
    if (isToSelf) {
      // We own every output here, so ownership cannot pick out the recipient.
      // Take the one that isn't change; falls back to the first output on
      // Liquid, where change cannot be identified.
      final paidOut = outputs.where((output) => !output.isChange);
      return paidOut.firstOrNull ?? outputs.first;
    }
    // The ownership flags can disagree with the direction heuristic (missed
    // self-transfers, unrecognized Liquid outputs, swap legs) — return null
    // instead of throwing so callers degrade to "no address".
    final matches = direction == WalletTransactionDirection.incoming
        ? outputs.where((output) => output.isOwn)
        : outputs.where((output) => !output.isOwn);
    return matches.firstOrNull;
  }

  String? get toAddress => destinationOutput?.address;

  List<Label>? get toAddressLabels => destinationOutput?.addressLabels;
}
