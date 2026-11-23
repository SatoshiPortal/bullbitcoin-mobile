import 'dart:io';

import 'package:backups/testing.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import '../../support/inventory_fixture.dart';

class _Settings implements ActiveEnvironmentReader {
  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => const Ok(Environment.testnet);
}

void main() {
  setUp(() => FakeSecureStoragePlatform().install());

  final legacyDate = DateTime.utc(2026, 1, 2);
  final physicalDate = DateTime.utc(2026, 2, 3);

  Future<BackupStatusSummary> summary(
    rb.BackupStatus status, {
    BitcoinNetwork network = BitcoinNetwork.testnet,
    bool physicalVerified = false,
    void Function(rb.VaultContext)? onReadVault,
  }) async {
    final directory = await Directory.systemTemp.createTemp('backup-status-');
    addTearDown(() => directory.delete(recursive: true));
    final fixture = await InventoryFixture.open(directory);
    addTearDown(fixture.close);
    final registered = await fixture.inventory.registerWallet(
      RegisteredWallet(
        id: 'wpkh([deadbeef/84h/1h/0h])',
        secretFingerprint: 'deadbeef',
        masterFingerprint: 'deadbeef',
        signer: 'local',
        network: network == BitcoinNetwork.testnet
            ? 'bitcoinTestnet'
            : 'bitcoinMainnet',
        xpub: 'unused-fixture',
        externalDescriptor: 'wpkh([deadbeef/84h/1h/0h]unused-fixture/0/*)',
        internalDescriptor: 'wpkh([deadbeef/84h/1h/0h]unused-fixture/1/*)',
        label: null,
        birthday: null,
        isDefault: true,
      ),
      prepareProperties: () async => const Ok(null),
    );
    expect(registered, isA<Ok>());
    final result = await ReadBackupStatusUsecase(
      fixture.inventory,
      _Settings(),
      (network, fingerprint) async {
        expect(network, BitcoinNetwork.testnet);
        expect(fingerprint.hex, 'deadbeef');
        return Ok((
          physicalBackupTested: physicalVerified,
          encryptedVaultTested: false,
          latestEncryptedBackup: legacyDate.millisecondsSinceEpoch,
          latestPhysicalBackup: physicalVerified
              ? physicalDate.millisecondsSinceEpoch
              : null,
        ));
      },
      (context) async {
        onReadVault?.call(context);
        return Ok(status);
      },
    ).execute();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
  }

  test(
    'a vault only known from before the current system is historical',
    () async {
      final status = await summary(const rb.BackupStatus());
      expect(status.encryptedHistorical, isTrue);
      expect(status.encryptedVerified, isFalse);
      expect(status.encryptedAt, legacyDate);
    },
  );

  test('a vault stored by the current system is merely untested', () async {
    final status = await summary(
      rb.BackupStatus(storedAt: DateTime.utc(2026, 11, 16)),
    );
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedVerified, isFalse);
  });

  test('a tested vault is neither historical nor untested', () async {
    final status = await summary(
      rb.BackupStatus(verifiedAt: DateTime.utc(2026, 11, 16)),
    );
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedVerified, isTrue);
  });

  test('physical facts do not stand in for encrypted verification', () async {
    final status = await summary(
      const rb.BackupStatus(),
      physicalVerified: true,
      onReadVault: (context) {
        expect(context.fingerprint.hex, 'deadbeef');
      },
    );
    expect(status.physicalVerified, isTrue);
    expect(status.physicalAt, physicalDate);
    expect(status.encryptedVerified, isFalse);
  });

  test('a default on another network cannot contribute backup facts', () async {
    final status = await summary(
      const rb.BackupStatus(),
      network: BitcoinNetwork.mainnet,
      physicalVerified: true,
      onReadVault: (_) => fail('A different network must not open a vault'),
    );
    expect(status.physicalVerified, isFalse);
    expect(status.physicalAt, isNull);
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedAt, isNull);
  });
}
