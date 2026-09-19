import 'dart:convert';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_metadata_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_record_mapper.dart';
import 'package:bb_mobile/features/bullvault/data/bullvault_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_recovery_package.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/update_bullvault_setup_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/verify_bullvault_descriptor_backup_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bullvault_test_fixture.dart';

class _Descriptors extends Fake implements BitcoinDescriptorPort {
  @override
  ({
    String descriptor,
    ScriptType? scriptType,
    List<WalletDescriptorKey> descriptorKeys,
    bool inferredChangePath,
  })
  parseBitcoinDescriptor({
    required String descriptor,
    required Network network,
  }) => parseTestBullVaultDescriptor(descriptor: descriptor, network: network);
}

class _Wallets extends Fake implements GetWalletUsecase {}

class _CountingRecords extends Fake implements BullVaultRepository {
  final BullVaultRepository delegate;
  int loads = 0;
  _CountingRecords(this.delegate);

  @override
  Future<Result<void, BullVaultFailure>> save(BullVaultRecord record) =>
      delegate.save(record);
  @override
  Future<Result<BullVaultRecord?, BullVaultFailure>> getByWalletId(String id) {
    loads++;
    return delegate.getByWalletId(id);
  }

  @override
  Result<BullVaultRecoveryPackage, BullVaultFailure> decodeRecoveryPackage(
    String source,
  ) => delegate.decodeRecoveryPackage(source);
  @override
  String encodeRecoveryPackage(BullVaultRecoveryPackage package) =>
      delegate.encodeRecoveryPackage(package);
  @override
  Future<Result<DateTime, BullVaultFailure>> recordBackupTest({
    required BullVaultRecord expected,
    required BullVaultBackupTestKind kind,
    required DateTime testedAt,
  }) => delegate.recordBackupTest(
    expected: expected,
    kind: kind,
    testedAt: testedAt,
  );
}

void main() {
  late SqliteDatabase database;
  late BullVaultRepositoryImpl repository;
  late _CountingRecords records;
  late VerifyBullVaultDescriptorBackupUsecase verify;
  late BullVaultRecord original;
  final now = DateTime.utc(2026, 9, 18, 12);
  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    final codec = testBullVaultRecoveryPackageCodec();
    repository = BullVaultRepositoryImpl(
      BullVaultMetadataDatasource(database),
      BullVaultRecordMapper(codec),
      codec,
    );
    final mapper = BullVaultRecordMapper(codec);
    // Creation persists the parser's canonical descriptor, not the raw template.
    original = mapper.toEntity(
      mapper.toModel(
        testBullVaultCreateResult(
          walletId: 'selected',
          usesBullMobile: false,
        ).record,
      ),
    );
    await database
        .into(database.walletMetadatas)
        .insert(
          WalletMetadatasCompanion.insert(
            id: original.walletId,
            network: Network.bitcoinMainnet,
            publicDescriptor: original.recoveryPackage.policy.descriptor,
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            isDefault: false,
          ),
        );
    expect(await repository.save(original), isA<Ok>());
    records = _CountingRecords(repository);
    verify = VerifyBullVaultDescriptorBackupUsecase(
      records,
      _Descriptors(),
      clock: () => now,
    );
  });
  tearDown(() => database.close());
  Future<BullVaultRecord> read() async =>
      (await repository.getByWalletId('selected')
              as Ok<BullVaultRecord?, BullVaultFailure>)
          .value!;

  test(
    'canonical descriptor match reuses the inspected record and records only the local descriptor date',
    () async {
      final result = await verify.execute(
        expected: await read(),
        source: original.recoveryPackage.policy.descriptor,
      );
      expect(result, isA<Ok<DateTime, BullVaultFailure>>());
      expect((result as Ok<DateTime, BullVaultFailure>).value, now);
      expect(records.loads, 0);
      final stored = await read();
      expect(stored.descriptorTestedAt, now);
      expect(stored.serverTestedAt, isNull);
      expect(stored.recoveryPackageConfirmed, isFalse);
    },
  );
  test('matching native recovery package tolerates JSON formatting', () async {
    final source = jsonEncode(
      jsonDecode(repository.encodeRecoveryPackage(original.recoveryPackage)),
    );
    expect(
      await verify.execute(expected: await read(), source: source),
      isA<Ok<DateTime, BullVaultFailure>>(),
    );
    expect((await read()).descriptorTestedAt, now);
  });
  test(
    'wrong descriptor, network, package metadata and empty input never record a date',
    () async {
      final other = testBullVaultCreateResult(includesInheritance: true).record;
      final wrongNetwork = testBullVaultCreateResult(
        network: Network.bitcoinTestnet,
      ).record;
      final model =
          jsonDecode(repository.encodeRecoveryPackage(original.recoveryPackage))
              as Map<String, dynamic>;
      model['lineageId'] = 'unrelated-lineage';
      for (final source in [
        other.recoveryPackage.policy.descriptor,
        wrongNetwork.recoveryPackage.policy.descriptor,
        repository.encodeRecoveryPackage(wrongNetwork.recoveryPackage),
        jsonEncode(model),
        '',
        'not a descriptor',
      ]) {
        expect(
          await verify.execute(expected: await read(), source: source),
          isA<Err<DateTime, BullVaultFailure>>(),
        );
        expect((await read()).descriptorTestedAt, isNull);
      }
    },
  );
  test('oversized input and missing vault cannot create a receipt', () async {
    expect(
      await verify.execute(
        expected: await read(),
        source: 'x' * (1024 * 1024 + 1),
      ),
      isA<Err<DateTime, BullVaultFailure>>(),
    );
    expect(
      await verify.execute(
        expected: testBullVaultCreateResult(walletId: 'missing').record,
        source: original.recoveryPackage.policy.descriptor,
      ),
      isA<Err<DateTime, BullVaultFailure>>(),
    );
    expect((await read()).descriptorTestedAt, isNull);
  });
  test('a changed vault package rejects the stale inspected record', () async {
    final inspected = await read();
    final changed = testBullVaultCreateResult(
      walletId: 'selected',
      lineageId: original.lineageId,
      usesBullMobile: false,
      includesInheritance: true,
    ).record;
    expect(await repository.save(changed), isA<Ok>());
    expect(
      await verify.execute(
        expected: inspected,
        source: inspected.recoveryPackage.policy.descriptor,
      ),
      isA<Err<DateTime, BullVaultFailure>>(),
    );
    expect((await read()).descriptorTestedAt, isNull);
  });

  test(
    'the completion flag alone is rejected until a descriptor copy is verified',
    () async {
      final setup = UpdateBullVaultSetupUsecase(records, _Wallets(), verify);
      expect(
        await setup.execute(
          walletId: 'selected',
          recoveryPackageConfirmed: true,
        ),
        isA<Err<BullVaultRecord, BullVaultFailure>>(),
      );
      expect((await read()).recoveryPackageConfirmed, isFalse);
      expect(
        await verify.execute(
          expected: await read(),
          source: original.recoveryPackage.policy.descriptor,
        ),
        isA<Ok<DateTime, BullVaultFailure>>(),
      );
      records.loads = 0;
      final completed = await setup.execute(
        walletId: 'selected',
        recoveryPackageConfirmed: true,
        descriptorReadBack: original.recoveryPackage.policy.descriptor,
      );
      expect(completed, isA<Ok<BullVaultRecord, BullVaultFailure>>());
      expect(
        (completed as Ok<BullVaultRecord, BullVaultFailure>)
            .value
            .descriptorTestedAt,
        now,
      );
      expect(records.loads, 1);
      expect((await read()).recoveryPackageConfirmed, isTrue);
      expect((await read()).descriptorTestedAt, now);
    },
  );
  test(
    'a server descriptor check writes only the selected server receipt',
    () async {
      final selected = await read();
      final result = await verify.execute(
        expected: selected,
        source: selected.recoveryPackage.policy.descriptor,
        kind: BullVaultBackupTestKind.server,
      );
      expect(result, isA<Ok<DateTime, BullVaultFailure>>());
      final stored = await read();
      expect(stored.serverTestedAt, now);
      expect(stored.descriptorTestedAt, isNull);
      expect(stored.recoveryPackageConfirmed, isFalse);
      expect(records.loads, 0);
      expect(selected.copyWith(serverTestedAt: now).serverTestedAt, now);
      expect(selected.serverTestedAt, isNull);
    },
  );

  test('server mismatch cannot update either receipt', () async {
    final other = testBullVaultCreateResult(includesInheritance: true).record;
    expect(
      await verify.execute(
        expected: await read(),
        source: other.recoveryPackage.policy.descriptor,
        kind: BullVaultBackupTestKind.server,
      ),
      isA<Err<DateTime, BullVaultFailure>>(),
    );
    final stored = await read();
    expect(stored.serverTestedAt, isNull);
    expect(stored.descriptorTestedAt, isNull);
  });
}
