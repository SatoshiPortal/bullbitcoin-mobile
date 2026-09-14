import 'dart:convert';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_vaults_section.dart';

/// A vaults section under test control: whatever [entries] hold is what the
/// snapshot carries; every restore is recorded and answered from [outcomes].
final class FakeBullVaultBackupSection implements BullVaultBackupSection {
  List<WalletBackupVaultEntry> entries = [];
  WalletBackupFailure? readFailure;
  final List<WalletBackupVaultEntry> restored = [];
  Network network = Network.bitcoinMainnet;

  /// Wallet refs whose restore should fail.
  final Set<String> failing = {};

  /// Wallet refs that already exist locally (restore then does not "create").
  final Set<String> existing = {};

  @override
  Future<Result<List<WalletBackupVaultEntry>, WalletBackupFailure>>
  read() async {
    final failure = readFailure;
    if (failure != null) return Err(failure);
    return Ok(List.unmodifiable(entries));
  }

  @override
  Future<Result<WalletVaultsRecoveryResult, WalletBackupFailure>> recover(
    List<WalletBackupVaultEntry> entries, {
    DateTime? deadline,
  }) async {
    var restoredCount = 0;
    var skipped = 0;
    var failed = 0;
    final created = <WalletPreferences>[];
    for (final entry in [...entries]..sort(WalletBackupVaultEntry.compare)) {
      if (entry.network != network) {
        skipped++;
        continue;
      }
      restored.add(entry);
      if (failing.contains(entry.walletRef)) {
        failed++;
        continue;
      }
      restoredCount++;
      if (!existing.contains(entry.walletRef)) {
        created.add(
          WalletPreferences(
            walletRef: entry.walletRef,
            label: entry.label ?? 'BullVault',
          ),
        );
      }
    }
    return Ok(
      WalletVaultsRecoveryResult(
        restoredCount: restoredCount,
        skippedCount: skipped,
        failedCount: failed,
        createdWalletPreferences: created,
      ),
    );
  }
}

/// A stand-in recovery package: plain JSON carrying the facts the backup
/// frames, so codec tests need no real vault policy.
String fakeVaultPackage({
  required String lineageId,
  required int vaultGeneration,
  Network network = Network.bitcoinMainnet,
  String descriptor = 'tr(fake)',
  int? birthHeight = 800000,
}) => jsonEncode({
  'lineageId': lineageId,
  'vaultGeneration': vaultGeneration,
  'network': network.name,
  'descriptor': descriptor,
  'birthHeight': birthHeight,
});

WalletBackupVaultPackageFacts? fakeVaultInspector(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final map = decoded;
  final network = Network.values
      .where((value) => value.name == map['network'])
      .firstOrNull;
  final lineageId = map['lineageId'];
  final generation = map['vaultGeneration'];
  final descriptor = map['descriptor'];
  if (network == null ||
      lineageId is! String ||
      generation is! int ||
      descriptor is! String) {
    return null;
  }
  return WalletBackupVaultPackageFacts(
    network: network,
    lineageId: lineageId,
    vaultGeneration: generation,
    descriptor: descriptor,
    birthHeight: map['birthHeight'] as int?,
  );
}

WalletBackupVaultPackageFacts? noVaultInspector(String source) => null;

WalletBackupVaultEntry fakeVaultEntry({
  required String walletRef,
  String? label,
  String status = 'active',
  Network network = Network.bitcoinMainnet,
  String lineageId = 'lineage-1',
  int vaultGeneration = 0,
  List<WalletBackupVaultSigner> signers = const [],
}) => WalletBackupVaultEntry(
  walletRef: walletRef,
  label: label,
  status: status,
  network: network,
  lineageId: lineageId,
  vaultGeneration: vaultGeneration,
  signers: signers,
  recoveryPackage: fakeVaultPackage(
    lineageId: lineageId,
    vaultGeneration: vaultGeneration,
    network: network,
  ),
);

/// One remote signer holding the whole descriptor, the shape a hardware
/// wallet definition has.
WalletSigner singleRemoteSigner(
  SignerDeviceEntity device, {
  String masterFingerprint = '86241f88',
  String xpubFingerprint = '11223344',
  String xpub =
      'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7',
}) => WalletSigner.single(
  masterFingerprint: masterFingerprint,
  xpubFingerprint: xpubFingerprint,
  xpub: xpub,
  derivationPath: "m/84'/0'/0'",
  descriptorPath: '/<0;1>/*',
  signer: SignerEntity.remote,
  signerDevice: device,
);
