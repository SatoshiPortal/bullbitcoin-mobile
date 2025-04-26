// ignore_for_file: invalid_annotation_target

import 'package:bb_mobile/core/labels/domain/labelable.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_input.dart';
import 'package:bb_mobile/core/wallet/domain/entities/transaction_output.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_entity.freezed.dart';

enum LabelType {
  tx,
  addr,
  pubkey,
  input,
  output,
  xpub;

  factory LabelType.fromName(String name) {
    return LabelType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => throw ArgumentError('Invalid label type: $name'),
    );
  }

  factory LabelType.fromLabelable(Labelable labelable) {
    if (labelable is WalletTransaction) {
      return LabelType.tx;
    } else if (labelable is WalletAddress) {
      return LabelType.addr;
    } else if (labelable is TransactionInput) {
      return LabelType.input;
    } else if (labelable is TransactionOutput) {
      return LabelType.output;
    }

    throw ArgumentError('Invalid type: $labelable');
  }
}

// BIP329 Standard Label
@freezed
sealed class Label with _$Label {
  const factory Label({
    required LabelType type,
    required String label,
    String? origin,
    bool? spendable,
  }) = _Label;
  const Label._();
}
