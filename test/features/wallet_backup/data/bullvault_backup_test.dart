import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/bullvault_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_vault_entry.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault/bullvault_test_fixture.dart';
import '../support/fake_bullvault_backup.dart';

BullVaultRecord _record({
  required String walletId,
  required String lineageId,
  required int generation,
  BullVaultLifecycleStatus status = BullVaultLifecycleStatus.active,
  String? previousVaultId,
}) {
  final package = testBullVaultRecoveryPackage(
    lineageId: lineageId,
    generation: generation,
    previousVaultId: previousVaultId,
  );
  return BullVaultRecord(
    walletId: walletId,
    lineageId: package.policy.lineageId,
    vaultGeneration: generation,
    mobileAccount: 0,
    birthHeight: package.policy.birthHeight,
    recoveryPackage: package,
    previousVaultId: previousVaultId,
    status: status,
    createdAt: DateTime.utc(2027),
  );
}

Future<void> _unusedDevice({
  required String walletId,
  required String signerId,
  required SignerDeviceEntity? signerDevice,
}) async => fail('no annotation was expected');

Future<void> _unusedRegistration({
  required String walletId,
  required String signerId,
  required String registrationName,
}) async => fail('no annotation was expected');

Wallet _wallet(
  String id, {
  String? label,
  List<WalletSigner> signers = const [],
}) => Wallet(
  origin: id,
  label: label,
  network: Network.bitcoinMainnet,
  signers: signers,
  scriptType: null,
  publicDescriptor: 'tr(vault)',
  balanceSat: BigInt.zero,
);

void main() {
  final codec = testBullVaultRecoveryPackageCodec();

  test('read carries every record, its label and status, verbatim', () async {
    final active = _record(
      walletId: 'v-1',
      lineageId: 'a',
      generation: 1,
      previousVaultId: 'v-0',
    );
    final retired = _record(
      walletId: 'v-0',
      lineageId: active.lineageId,
      generation: 0,
      status: BullVaultLifecycleStatus.migrating,
    );
    final section = BullVaultBackupImpl(
      listRecords: () async => Ok([active, retired]),
      encodePackage: codec.encode,
      wallet: (walletId) async =>
          walletId == 'v-1' ? _wallet('v-1', label: 'Everyday') : null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) =>
          throw StateError('no'),
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    final entries = (await section.read() as Ok).value;

    expect(entries.map((entry) => entry.walletRef), ['v-0', 'v-1']);
    expect(entries.last.label, 'Everyday');
    expect(entries.first.status, 'migrating');
    expect(
      entries.first.recoveryPackage,
      codec.encode(retired.recoveryPackage),
    );
    expect(entries.last.vaultGeneration, 1);
  });

  test('read carries each signer device and registration name', () async {
    final active = _record(walletId: 'v-1', lineageId: 'a', generation: 0);
    final section = BullVaultBackupImpl(
      listRecords: () async => Ok([active]),
      encodePackage: codec.encode,
      wallet: (_) async => _wallet(
        'v-1',
        label: 'Everyday',
        signers: [
          WalletSigner.single(
            id: 'signer-cold',
            descriptorKeyId: 'key-cold',
            masterFingerprint: '73c5da0a',
            xpubFingerprint: '73c5da0a',
            xpub: 'xpub-cold',
            signer: SignerEntity.remote,
            signerDevice: SignerDeviceEntity.coldcardMk4,
            registrationName: 'Cold in the safe',
          ),
          WalletSigner.single(
            id: 'signer-phone',
            descriptorKeyId: 'key-phone',
            masterFingerprint: '73c5da0a',
            xpubFingerprint: '73c5da0a',
            xpub: 'xpub-phone',
            signer: SignerEntity.local,
            signerDevice: null,
          ),
        ],
      ),
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) =>
          throw StateError('no'),
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    final entry =
        (await section.read() as Ok).value.single as WalletBackupVaultEntry;

    expect(entry.signers, hasLength(1));
    expect(entry.signers.single.accountXpub, 'xpub-cold');
    expect(entry.signers.single.signerDevice, SignerDeviceEntity.coldcardMk4);
    expect(entry.signers.single.registrationName, 'Cold in the safe');
  });

  test('recover puts each annotation back on its own signer', () async {
    final applied = <String, Object?>{};
    final section = BullVaultBackupImpl(
      listRecords: () async => const Ok([]),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) async => Ok(
        BullVaultRestoreResult(
          wallet: _wallet(
            'restored',
            signers: [
              WalletSigner.single(
                id: 'new-signer-id',
                descriptorKeyId: 'key-cold',
                masterFingerprint: '73c5da0a',
                xpubFingerprint: '73c5da0a',
                xpub: 'xpub-cold',
                signer: SignerEntity.remote,
                signerDevice: null,
              ),
            ],
          ),
          record: _record(walletId: 'restored', lineageId: 'a', generation: 0),
          mobileAccess: BullVaultMobileAccess.unavailable,
        ),
      ),
      setSignerDevice:
          ({
            required walletId,
            required signerId,
            required signerDevice,
          }) async {
            applied['device'] = '$walletId/$signerId/${signerDevice?.name}';
          },
      setSignerRegistrationName:
          ({
            required walletId,
            required signerId,
            required registrationName,
          }) async {
            applied['name'] = '$walletId/$signerId/$registrationName';
          },
    );

    await section.recover([
      fakeVaultEntry(
        walletRef: 'restored',
        signers: [
          WalletBackupVaultSigner(
            accountXpub: 'xpub-cold',
            signerDevice: SignerDeviceEntity.coldcardMk4,
            registrationName: 'Cold in the safe',
          ),
        ],
      ),
    ]);

    expect(applied['device'], 'restored/new-signer-id/coldcardMk4');
    expect(applied['name'], 'restored/new-signer-id/Cold in the safe');
  });

  test('read reports a vault failure as a backup failure', () async {
    final section = BullVaultBackupImpl(
      listRecords: () async => const Err(BullVaultRenewalFailure()),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) =>
          throw StateError('no'),
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    expect(
      await section.read(),
      isA<Err<Object?, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupVaultsFailure>(),
      ),
    );
  });

  test(
    'recover replays in generation order, skips other networks and counts',
    () async {
      final restored = <String>[];
      final section = BullVaultBackupImpl(
        listRecords: () async => const Ok([]),
        encodePackage: codec.encode,
        wallet: (_) async => null,
        currentNetwork: () async => Network.bitcoinMainnet,
        walletExists: (walletId) async => walletId == 'already-here',
        restore: ({required source, required label, required status}) async {
          restored.add('$label:$source');
          if (label == 'broken') {
            return const Err(BullVaultInvalidRecoveryFailure());
          }
          final record = _record(
            walletId: label,
            lineageId: 'x',
            generation: 0,
          );
          return Ok(
            BullVaultRestoreResult(
              wallet: _wallet(label),
              record: record,
              mobileAccess: BullVaultMobileAccess.unavailable,
            ),
          );
        },
        setSignerDevice: _unusedDevice,
        setSignerRegistrationName: _unusedRegistration,
      );

      final result =
          (await section.recover([
                    fakeVaultEntry(
                      walletRef: 'gen-1',
                      label: 'gen-1',
                      lineageId: 'a',
                      vaultGeneration: 1,
                    ),
                    fakeVaultEntry(
                      walletRef: 'gen-0',
                      label: 'gen-0',
                      lineageId: 'a',
                      vaultGeneration: 0,
                    ),
                    fakeVaultEntry(
                      walletRef: 'testnet',
                      label: 'testnet',
                      lineageId: 't',
                      network: Network.bitcoinTestnet,
                    ),
                    fakeVaultEntry(
                      walletRef: 'broken',
                      label: 'broken',
                      lineageId: 'b',
                    ),
                    fakeVaultEntry(
                      walletRef: 'already-here',
                      label: 'already-here',
                      lineageId: 'c',
                    ),
                  ])
                  as Ok)
              .value;

      expect(
        restored.map((call) => call.split(':').first),
        ['gen-0', 'gen-1', 'broken', 'already-here'],
        reason: 'predecessor first; the testnet vault is never attempted',
      );
      expect(result.restoredCount, 3);
      expect(result.skippedCount, 1);
      expect(result.failedCount, 1);
      expect(
        (result.createdWalletPreferences as List<WalletPreferences>).map(
          (item) => item.walletRef,
        ),
        ['gen-0', 'gen-1'],
        reason: 'a wallet that already existed is not reported as created',
      );
    },
  );

  test('recover replays each generation under its backed-up status', () async {
    final replayed = <String, BullVaultLifecycleStatus>{};
    final section = BullVaultBackupImpl(
      listRecords: () async => const Ok([]),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) async {
        replayed[label] = status;
        return Ok(
          BullVaultRestoreResult(
            wallet: _wallet(label),
            record: _record(walletId: label, lineageId: 'a', generation: 0),
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        );
      },
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    await section.recover([
      fakeVaultEntry(
        walletRef: 'gen-0',
        label: 'gen-0',
        lineageId: 'a',
        vaultGeneration: 0,
        status: 'migrating',
      ),
      fakeVaultEntry(
        walletRef: 'gen-1',
        label: 'gen-1',
        lineageId: 'a',
        vaultGeneration: 1,
        status: 'active',
      ),
      fakeVaultEntry(
        walletRef: 'gen-2',
        label: 'gen-2',
        lineageId: 'a',
        vaultGeneration: 2,
        status: 'pending',
      ),
    ]);

    expect(replayed, {
      'gen-0': BullVaultLifecycleStatus.migrating,
      'gen-1': BullVaultLifecycleStatus.active,
      'gen-2': BullVaultLifecycleStatus.pending,
    });
  });

  test('recover never guesses a status this build cannot read', () async {
    var attempts = 0;
    final section = BullVaultBackupImpl(
      listRecords: () async => const Ok([]),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) async {
        attempts++;
        return const Err(BullVaultInvalidRecoveryFailure());
      },
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    final result =
        (await section.recover([
                  fakeVaultEntry(walletRef: 'v', status: 'hibernating'),
                ])
                as Ok)
            .value;

    expect(attempts, 0);
    expect(result.failedCount, 1);
    expect(result.restoredCount, 0);
  });

  test('recover uses a fallback label when the backup has none', () async {
    String? seen;
    final section = BullVaultBackupImpl(
      listRecords: () async => const Ok([]),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) async {
        seen = label;
        return const Err(BullVaultInvalidRecoveryFailure());
      },
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
    );

    await section.recover([fakeVaultEntry(walletRef: 'v')]);

    expect(seen, BullVaultBackupImpl.fallbackLabel);
  });

  test('recover stops at the deadline and counts the rest as failed', () async {
    var now = DateTime.utc(2027);
    final section = BullVaultBackupImpl(
      listRecords: () async => const Ok([]),
      encodePackage: codec.encode,
      wallet: (_) async => null,
      currentNetwork: () async => Network.bitcoinMainnet,
      walletExists: (_) async => false,
      restore: ({required source, required label, required status}) async {
        now = now.add(const Duration(minutes: 5));
        return Ok(
          BullVaultRestoreResult(
            wallet: _wallet(label),
            record: _record(walletId: label, lineageId: 'x', generation: 0),
            mobileAccess: BullVaultMobileAccess.unavailable,
          ),
        );
      },
      setSignerDevice: _unusedDevice,
      setSignerRegistrationName: _unusedRegistration,
      nowUtc: () => now,
    );

    final result =
        (await section.recover([
                  fakeVaultEntry(
                    walletRef: 'first',
                    label: 'first',
                    lineageId: 'a',
                  ),
                  fakeVaultEntry(
                    walletRef: 'second',
                    label: 'second',
                    lineageId: 'b',
                  ),
                ], deadline: DateTime.utc(2027).add(const Duration(minutes: 1)))
                as Ok)
            .value;

    expect(result.restoredCount, 1);
    expect(result.failedCount, 1);
  });
}
