import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';

WalletSignerModel walletSignerModel({
  required String id,
  required String descriptorKeyId,
  required String masterFingerprint,
  required String xpubFingerprint,
  required String xpub,
  String? derivationPath,
  String descriptorPath = '',
  required Signer signer,
  required SignerDevice? signerDevice,
  String? registrationName,
  String? localSeedFingerprint,
  bool requiresPassphrase = false,
}) => WalletSignerModel(
  id: id,
  signer: signer,
  signerDevice: signerDevice,
  registrationName: registrationName,
  localSeedFingerprint: localSeedFingerprint,
  descriptorKeys: [
    WalletDescriptorKeyModel(
      id: descriptorKeyId,
      signerId: id,
      masterFingerprint: masterFingerprint,
      xpubFingerprint: xpubFingerprint,
      xpub: xpub,
      derivationPath: derivationPath,
      descriptorPath: descriptorPath,
      requiresPassphrase: requiresPassphrase,
    ),
  ],
);
