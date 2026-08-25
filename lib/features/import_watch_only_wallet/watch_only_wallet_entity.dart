import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch_only_wallet_entity.freezed.dart';

@freezed
sealed class WatchOnlyWalletEntity with _$WatchOnlyWalletEntity {
  const factory WatchOnlyWalletEntity.descriptor({
    required String descriptor,
    required Network network,
    required ScriptType? scriptType,
    required List<WalletSigner> signers,
    @Default(false) bool inferredChangePath,
    @Default('') String label,
  }) = WatchOnlyDescriptorEntity;

  const factory WatchOnlyWalletEntity.xpub({
    required String extendedPublicKey,
    required String canonicalXpub,
    required Network network,
    required ScriptType scriptType,
    String? masterFingerprint,
    String? derivationPath,
    @Default(SignerEntity.none) SignerEntity signer,
    SignerDeviceEntity? signerDevice,
    @Default('') String label,
  }) = WatchOnlyXpubEntity;

  const WatchOnlyWalletEntity._();
}

extension WatchOnlyXpubEntityExtension on WatchOnlyXpubEntity {
  WatchOnlyWalletEntity withScriptType(ScriptType value) {
    final accountKey = Bip32Derivation.getBip32Xpub(canonicalXpub);
    return copyWith(
      extendedPublicKey: accountKey.convert(value.getXpubType(network)),
      scriptType: value,
    );
  }
}

extension WatchOnlyDescriptorEntityExtension on WatchOnlyDescriptorEntity {
  WatchOnlyDescriptorEntity withSignerDevice({
    required String signerId,
    required SignerDeviceEntity? signerDevice,
  }) {
    final matching = signers.where((signer) => signer.id == signerId);
    if (matching.any((signer) => signer.signer == SignerEntity.local)) {
      return this;
    }

    return copyWith(
      signers: [
        for (final signer in signers)
          if (signer.id == signerId)
            signer.copyWith(
              signerDevice: signerDevice,
              clearSignerDevice: signerDevice == null,
            )
          else
            signer,
      ],
    );
  }
}
