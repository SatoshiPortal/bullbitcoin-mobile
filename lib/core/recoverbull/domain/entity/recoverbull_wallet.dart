import 'package:freezed_annotation/freezed_annotation.dart';

part 'recoverbull_wallet.freezed.dart';
part 'recoverbull_wallet.g.dart';

@freezed
abstract class RecoverBullWallet with _$RecoverBullWallet {
  const factory RecoverBullWallet({
    @Default([]) List<String> mnemonic,
    // TODO(azad): masterFingerprint should be computed from mnemonic
    @Default('') String masterFingerprint,
    @Default(false) bool isEncryptedVaultTested,
    @Default(false) bool isPhysicalBackupTested,
    DateTime? latestEncryptedBackup,
    DateTime? latestPhysicalBackup,
  }) = _RecoverBullWallet;

  factory RecoverBullWallet.fromJson(Map<String, dynamic> json) =>
      _$RecoverBullWalletFromJson(json);
}
