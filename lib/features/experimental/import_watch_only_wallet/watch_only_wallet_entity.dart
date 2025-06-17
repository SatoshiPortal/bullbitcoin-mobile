import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch_only_wallet_entity.freezed.dart';

@freezed
abstract class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity({
    required String pubkey,
    required String fingerprint,
    required ScriptType type,
    @Default('') String label,
  }) = _WatchOnlyWalletEntity;

  const WatchOnlyWalletEntity._();

  factory WatchOnlyWalletEntity.from(
    String extendedPublicKey, {
    String label = '',
  }) {
    return WatchOnlyWalletEntity(
      pubkey: extendedPublicKey,
      fingerprint: _getPubkeyFingerprint(extendedPublicKey),
      type: ScriptType.fromExtendedPublicKey(extendedPublicKey),
      label: label,
    );
  }

  static String _getPubkeyFingerprint(String pubkey) {
    final bip32Xpub = Bip32Derivation.getBip32Xpub(pubkey);
    return bip32Xpub.fingerprintHex;
  }

  bool get canGenerateValidPsbt {
    // If the fingerprint is generated from the pubkey
    // it means the wallet is NOT valid to generate PSBT
    return _getPubkeyFingerprint(pubkey) != fingerprint;
  }
}
