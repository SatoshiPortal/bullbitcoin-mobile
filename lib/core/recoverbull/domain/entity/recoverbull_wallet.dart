import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recoverbull_wallet.freezed.dart';
part 'recoverbull_wallet.g.dart';

@freezed
class RecoverBullWallet with _$RecoverBullWallet {
  const factory RecoverBullWallet({
    @Default([]) List<String> mnemonic,
    required WalletMetadata metadata,
  }) = _RecoverBullWallet;

  factory RecoverBullWallet.fromJson(Map<String, dynamic> json) =>
      _$RecoverBullWalletFromJson(json);
}
