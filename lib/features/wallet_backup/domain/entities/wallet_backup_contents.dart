import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';

final class WalletBackupContents {
  final List<WalletBackupWalletSummary> wallets;
  final int labelCount;
  final int frozenCoinCount;
  final int walletPreferenceCount;
  final WalletPortableSettings? settings;

  const WalletBackupContents({
    this.wallets = const [],
    required this.labelCount,
    required this.frozenCoinCount,
    required this.walletPreferenceCount,
    this.settings,
  });
}

final class WalletBackupWalletSummary {
  final String? label;
  final Network network;
  final WalletProvenance provenance;
  final bool keysOnDevice;
  final String? derivationPath;
  final String? descriptor;
  final SignerDeviceEntity? signerDevice;
  final bool? seedPassphraseUsed;

  const WalletBackupWalletSummary({
    this.label,
    required this.network,
    required this.provenance,
    required this.keysOnDevice,
    this.derivationPath,
    this.descriptor,
    this.signerDevice,
    this.seedPassphraseUsed,
  });
}
