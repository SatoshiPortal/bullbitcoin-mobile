import 'package:bb_mobile/_core/domain/entities/transaction.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';

@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String id,
    @Default('') String label,
    required Network network,
    @Default(false) bool isDefault,
    // The fingerprint of the BIP32 root/master key (if a seed was used to derive the wallet)
    @Default('') String masterFingerprint,
    required String xpubFingerprint,
    required ScriptType scriptType,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required WalletSource source,
    required BigInt balanceSat,
    @Default([]) List<Transaction> recentTransactions,
  }) = _Wallet;
  const Wallet._();
}
