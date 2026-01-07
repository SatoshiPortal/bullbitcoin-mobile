import 'package:bb_mobile/features/labels/domain/label.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
      return outputs.first;
    } else if (direction == WalletTransactionDirection.incoming) {
      return outputs.firstWhere((output) => output.isOwn);
    } else {
      return outputs.firstWhere((output) => !output.isOwn);
    }
  }

  String? get toAddress => destinationOutput?.address;

  List<Label>? get toAddressLabels => destinationOutput?.addressLabels;
}
