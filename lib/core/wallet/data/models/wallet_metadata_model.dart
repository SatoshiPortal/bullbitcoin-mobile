import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_signer_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';

@freezed
abstract class WalletMetadataModel with _$WalletMetadataModel {
  const factory WalletMetadataModel({
    required String id,
    required Network network,
    required List<WalletSignerModel> signers,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String publicDescriptor,
    required bool isDefault,
    @Default(false) bool isHidden,
    bool? hideOnHome,
    bool? autoSweepEnabled,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    DateTime? birthday,
    @Default(WalletProvenance.watchOnly) WalletProvenance provenance,
    bool? seedPassphraseUsed,
  }) = _WalletMetadataModel;

  const WalletMetadataModel._();
}

extension WalletMetadataModelExtension on WalletMetadataModel {
  bool get isBitcoin => network.isBitcoin;
  bool get isLiquid => network.isLiquid;
  bool get isMainnet => network.isMainnet;
  bool get isTestnet => network.isTestnet;

  /// Seed-derived wallets keep their BIP32 origin as the wallet id, so the
  /// account, fingerprint, network and script type can be read back from it.
  /// Throws for descriptor wallets, whose ids are not origins.
  ({String account, String fingerprint, Network network, ScriptType script})
  get decodeOrigin => WalletMetadataService.decodeOrigin(origin: id);

  /// The script type of a standard single-signature wallet, read from the
  /// origin id. Only meaningful for seed-derived wallets.
  ScriptType get scriptType => decodeOrigin.script;

  /// Facts of the primary (position 0) signer. For wallets migrated from the
  /// single-signer schema this is exactly the former `signer` column set.
  WalletSignerModel? get primarySigner =>
      signers.isEmpty ? null : signers.first;
  String get masterFingerprint =>
      primarySigner?.descriptorKeys.firstOrNull?.masterFingerprint ?? '';
  Signer get signer => primarySigner?.signer ?? Signer.none;
  SignerDevice? get signerDevice => primarySigner?.signerDevice;
}
