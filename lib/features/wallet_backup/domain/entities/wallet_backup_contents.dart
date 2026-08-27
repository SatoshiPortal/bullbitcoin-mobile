import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

final class WalletBackupContents {
  final List<WalletBackupWalletSummary> wallets;
  final List<WalletBackupMetadataSummary> metadata;

  WalletBackupContents({
    required List<WalletBackupWalletSummary> wallets,
    required List<WalletBackupMetadataSummary> metadata,
  }) : wallets = List.unmodifiable(wallets),
       metadata = List.unmodifiable(metadata);

  int get metadataRecordCount =>
      metadata.fold(0, (count, section) => count + section.recordCount);
}

final class WalletBackupWalletSummary {
  final String? label;
  final Network network;
  final WalletProvenance provenance;
  final SignerDeviceEntity? signerDevice;
  final DateTime? birthday;
  final bool? seedPassphraseUsed;

  const WalletBackupWalletSummary({
    this.label,
    required this.network,
    required this.provenance,
    this.signerDevice,
    this.birthday,
    this.seedPassphraseUsed,
  });

  bool get publicDefinitionIncluded => network.isBitcoin;
}

final class WalletBackupMetadataSummary {
  final String recordType;
  final int recordCount;

  const WalletBackupMetadataSummary({
    required this.recordType,
    required this.recordCount,
  });
}
