import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction.freezed.dart';

enum WalletTransactionDirection { incoming, outgoing }

enum WalletTransactionStatus {
  pending,
  confirmed;

  String displayName(BuildContext context) {
    switch (this) {
      case WalletTransactionStatus.pending:
        return context.loc.coreWalletTransactionStatusPending;
      case WalletTransactionStatus.confirmed:
        return context.loc.coreWalletTransactionStatusConfirmed;
    }
  }
}

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

    /// The transaction's `nLockTime`, and the height of the block that
    /// confirmed it.
    ///
    /// Together these bound when the sender broadcast an incoming payment,
    /// which the wallet cannot otherwise know. Bitcoin Core and Electrum set
    /// `nLockTime` to the chain tip when they *build* a transaction, so the
    /// height gap between the two is roughly how long it waited in the
    /// mempool. Null on Liquid, which confirms in about a minute and needs no
    /// such bound, and on any transaction the wallet read before this was
    /// recorded.
    int? lockTime,
    int? confirmationHeight,
    @Default(false) bool isToSelf,
    @Default([]) List<Label> labels,
    String? unblindedUrl,
  }) = _WalletTransaction;

  const WalletTransaction._();

  bool get isBitcoin => network.isBitcoin;
  bool get isLiquid => network.isLiquid;
  bool get isTestnet => network.isTestnet;
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
