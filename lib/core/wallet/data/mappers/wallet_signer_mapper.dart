import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

extension WalletDescriptorKeyModelMapper on WalletDescriptorKeyModel {
  WalletDescriptorKey toEntity() => WalletDescriptorKey(
    id: id,
    signerId: signerId,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    xpub: xpub,
    derivationPath: derivationPath,
    descriptorPath: descriptorPath,
    requiresPassphrase: requiresPassphrase,
  );
}

extension WalletDescriptorKeyMapper on WalletDescriptorKey {
  WalletDescriptorKeyModel toModel() => WalletDescriptorKeyModel(
    id: id,
    signerId: signerId,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    xpub: xpub,
    derivationPath: derivationPath,
    descriptorPath: descriptorPath,
    requiresPassphrase: requiresPassphrase,
  );
}

extension WalletSignerModelMapper on WalletSignerModel {
  WalletSigner toEntity() => WalletSigner(
    id: id,
    signer: signer.toEntity(),
    signerDevice: signerDevice?.toEntity(),
    registrationName: registrationName,
    localSeedFingerprint: localSeedFingerprint,
    descriptorKeys: descriptorKeys.map((key) => key.toEntity()).toList(),
  );
}

extension WalletSignerMapper on WalletSigner {
  WalletSignerModel toModel() => WalletSignerModel(
    id: id,
    signer: Signer.fromEntity(signer),
    signerDevice: signerDevice == null
        ? null
        : SignerDevice.fromEntity(signerDevice!),
    registrationName: registrationName,
    localSeedFingerprint: localSeedFingerprint,
    descriptorKeys: descriptorKeys.map((key) => key.toModel()).toList(),
  );
}
