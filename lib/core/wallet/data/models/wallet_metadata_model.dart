import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:drift/drift.dart' show Value;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_metadata_model.freezed.dart';

@freezed
abstract class WalletMetadataModel with _$WalletMetadataModel {
  const factory WalletMetadataModel({
    required String id,
    required String masterFingerprint,
    required String xpubFingerprint,
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    int? latestEncryptedBackup,
    int? latestPhysicalBackup,
    required String xpub,
    required String externalPublicDescriptor,
    required String internalPublicDescriptor,
    required Signer signer,
    required bool isDefault,
    @Default(0) int lastReceiveAddressIndex,
    String? label,
    DateTime? syncedAt,
    SignerDevice? signerDevice,
    DateTime? birthday,
    @Default(BitcoinSyncBackend.electrum) BitcoinSyncBackend bitcoinSyncBackend,
    DateTime? birthdayBlockTimestamp,
    int? birthdayBlockHeight,
    String? birthdayBlockHash,
  }) = _WalletMetadataModel;

  const WalletMetadataModel._();
}

extension WalletMetadataModelExtension on WalletMetadataModel {
  ({String account, String fingerprint, Network network, ScriptType script})
  get decodeOrigin => WalletMetadataService.decodeOrigin(origin: id);

  String get account => decodeOrigin.account;
  String get fingerprint => decodeOrigin.fingerprint;
  Network get network => decodeOrigin.network;
  ScriptType get scriptType => decodeOrigin.script;
  bool get isBitcoin => decodeOrigin.network.isBitcoin;
  bool get isLiquid => decodeOrigin.network.isLiquid;
  bool get isMainnet => decodeOrigin.network.isMainnet;
  bool get isTestnet => decodeOrigin.network.isTestnet;
}

extension WalletMetadataModelBirthdayCheckpoint on WalletMetadataModel {
  /// Builds the resolved [WalletBirthdayCheckpoint] for this wallet, or
  /// `null` if it hasn't been resolved yet — either [birthday] is unset, or
  /// any one of the three atomic `birthdayBlock*` fields is still unset.
  /// The three fields are always read together through this getter rather
  /// than individually, keeping the all-or-none invariant at the model
  /// boundary (mirrored by [copyWithBirthdayCheckpoint]).
  WalletBirthdayCheckpoint? get birthdayCheckpoint {
    final requestedBirthday = birthday;
    final blockTimestamp = birthdayBlockTimestamp;
    final blockHeight = birthdayBlockHeight;
    final blockHash = birthdayBlockHash;
    if (requestedBirthday == null ||
        blockTimestamp == null ||
        blockHeight == null ||
        blockHash == null) {
      return null;
    }

    return WalletBirthdayCheckpoint(
      requestedBirthday: requestedBirthday,
      blockTimestamp: blockTimestamp,
      blockHeight: blockHeight,
      blockHash: blockHash,
    );
  }

  /// Returns a copy of this model with all three atomic checkpoint fields
  /// set together from [checkpoint] — the only way to set them through
  /// this API, enforcing the all-or-none invariant at the model boundary.
  WalletMetadataModel copyWithBirthdayCheckpoint(
    WalletBirthdayCheckpoint checkpoint,
  ) {
    return copyWith(
      birthdayBlockTimestamp: checkpoint.blockTimestamp,
      birthdayBlockHeight: checkpoint.blockHeight,
      birthdayBlockHash: checkpoint.blockHash,
    );
  }
}

extension WalletMetadataModelMapper on WalletMetadataModel {
  WalletMetadatasCompanion toSqlite() => WalletMetadatasCompanion(
    id: Value(id),
    masterFingerprint: Value(masterFingerprint),
    xpubFingerprint: Value(xpubFingerprint),
    isEncryptedVaultTested: Value(isEncryptedVaultTested),
    isPhysicalBackupTested: Value(isPhysicalBackupTested),
    latestEncryptedBackup: Value(latestEncryptedBackup),
    latestPhysicalBackup: Value(latestPhysicalBackup),
    xpub: Value(xpub),
    externalPublicDescriptor: Value(externalPublicDescriptor),
    internalPublicDescriptor: Value(internalPublicDescriptor),
    signer: Value(signer.name),
    isDefault: Value(isDefault),
    label: Value(label),
    syncedAt: Value(syncedAt),
    signerDevice: Value(signerDevice),
    birthday: Value(birthday),
    bitcoinSyncBackend: Value(bitcoinSyncBackend),
    lastReceiveAddressIndex: Value(lastReceiveAddressIndex),
    birthdayBlockTimestamp: Value(birthdayBlockTimestamp),
    birthdayBlockHeight: Value(birthdayBlockHeight),
    birthdayBlockHash: Value(birthdayBlockHash),
  );

  static WalletMetadataModel fromSqlite(WalletMetadataRow row) =>
      WalletMetadataModel(
        id: row.id,
        masterFingerprint: row.masterFingerprint,
        xpubFingerprint: row.xpubFingerprint,
        isEncryptedVaultTested: row.isEncryptedVaultTested,
        isPhysicalBackupTested: row.isPhysicalBackupTested,
        latestEncryptedBackup: row.latestEncryptedBackup,
        latestPhysicalBackup: row.latestPhysicalBackup,
        xpub: row.xpub,
        externalPublicDescriptor: row.externalPublicDescriptor,
        internalPublicDescriptor: row.internalPublicDescriptor,
        signer: Signer.fromName(row.signer),
        isDefault: row.isDefault,
        label: row.label,
        syncedAt: row.syncedAt,
        signerDevice: row.signerDevice,
        birthday: row.birthday,
        bitcoinSyncBackend: row.bitcoinSyncBackend,
        lastReceiveAddressIndex: row.lastReceiveAddressIndex,
        birthdayBlockTimestamp: row.birthdayBlockTimestamp,
        birthdayBlockHeight: row.birthdayBlockHeight,
        birthdayBlockHash: row.birthdayBlockHash,
      );
}
