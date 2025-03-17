import 'dart:convert';

import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hex/hex.dart';

part 'recoverbull_wallet.freezed.dart';

@freezed
class RecoverBullWallet with _$RecoverBullWallet {
  const factory RecoverBullWallet({
    required List<int> seed,
    required WalletMetadata metadata,
  }) = _RecoverBullWallet;

  const RecoverBullWallet._();

  factory RecoverBullWallet.fromJson(Map<String, dynamic> json) {
    return RecoverBullWallet(
      seed: HEX.decode(json['seed'] as String),
      metadata: WalletMetadata.fromJson(
        jsonDecode(json['metadata'] as String) as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seed': HEX.decode(seed as String),
      'metadata': jsonEncode(metadata.toJson()),
    };
  }
}
