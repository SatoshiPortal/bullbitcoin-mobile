import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/wallet_preferences_repository_impl.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

void main() {
  test(
    'maps only exact nullable preferences from structural metadata',
    () async {
      final database = SqliteDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database
          .into(database.walletMetadatas)
          .insert(
            WalletMetadatasCompanion.insert(
              id: 'elwpkh([0f36572d/84h/1h/0h])',
              masterFingerprint: 'private-structure-master',
              xpubFingerprint: 'private-structure-xpub',
              isEncryptedVaultTested: true,
              isPhysicalBackupTested: true,
              latestEncryptedBackup: const Value(123),
              latestPhysicalBackup: const Value(456),
              xpub: 'private-structure-xpub-material',
              externalPublicDescriptor: 'private-structure-external-descriptor',
              internalPublicDescriptor: 'private-structure-internal-descriptor',
              signer: 'local',
              isDefault: true,
              hideOnHome: const Value(false),
              autoSweepEnabled: const Value(true),
              label: const Value('Point of Sale'),
              syncedAt: Value(DateTime.utc(2026)),
              birthday: Value(DateTime.utc(2020)),
            ),
          );
      await database
          .into(database.walletMetadatas)
          .insert(
            WalletMetadatasCompanion.insert(
              id: 'wpkh([aaaaaaaa/84h/0h/0h])',
              masterFingerprint: 'master',
              xpubFingerprint: 'xpub-fingerprint',
              isEncryptedVaultTested: false,
              isPhysicalBackupTested: false,
              xpub: 'xpub',
              externalPublicDescriptor: 'external',
              internalPublicDescriptor: 'internal',
              signer: 'none',
              isDefault: false,
            ),
          );
      final repository = WalletPreferencesRepositoryImpl(
        WalletMetadataDatasource(sqlite: database),
      );

      final result = await repository.fetchAll();

      expect(
        result,
        isA<Ok<List<WalletPreferences>, WalletPreferencesFailure>>(),
      );
      final preferences =
          (result as Ok<List<WalletPreferences>, WalletPreferencesFailure>)
              .value;
      expect(preferences, hasLength(2));
      final represented = preferences.first;
      expect(represented.walletRef, 'elwpkh([0f36572d/84h/1h/0h])');
      expect(represented.label, 'Point of Sale');
      expect(represented.hideOnHome, isFalse);
      expect(represented.autoSweepEnabled, isTrue);
      expect(represented.hasRepresentedValue, isTrue);
      final absent = preferences.last;
      expect(absent.label, isNull);
      expect(absent.hideOnHome, isNull);
      expect(absent.autoSweepEnabled, isNull);
      expect(absent.hasRepresentedValue, isFalse);
    },
  );

  test('maps datasource failure to a typed storage failure', () async {
    final datasource = _MockWalletMetadataDatasource();
    when(
      () => datasource.fetchAll(),
    ).thenThrow(Exception('private metadata row and database path'));
    final repository = WalletPreferencesRepositoryImpl(datasource);

    final result = await repository.fetchAll();

    expect(
      result,
      isA<Err<List<WalletPreferences>, WalletPreferencesFailure>>(),
    );
    expect(
      (result as Err<List<WalletPreferences>, WalletPreferencesFailure>)
          .failure,
      isA<WalletPreferencesStorageFailure>(),
    );
  });

  test('atomically replaces only the recovered nullable fields', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertWalletMetadata(
      database,
      walletRef: 'wallet-a',
      label: 'product default',
      hideOnHome: true,
      autoSweepEnabled: true,
    );
    final repository = WalletPreferencesRepositoryImpl(
      WalletMetadataDatasource(sqlite: database),
    );

    final result = await repository.applyRecovered([
      WalletPreferences(walletRef: 'wallet-a', hideOnHome: false),
    ]);
    final row = await database.select(database.walletMetadatas).getSingle();

    expect(result, isA<Ok<Null, WalletPreferencesFailure>>());
    expect(row.label, isNull);
    expect(row.hideOnHome, isFalse);
    expect(row.autoSweepEnabled, isNull);
    expect(row.xpub, 'structural-xpub');
    expect(row.externalPublicDescriptor, 'structural-external');
  });

  test('a missing wallet rolls back the whole recovered batch', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertWalletMetadata(
      database,
      walletRef: 'wallet-a',
      label: 'local',
      hideOnHome: true,
      autoSweepEnabled: false,
    );
    final repository = WalletPreferencesRepositoryImpl(
      WalletMetadataDatasource(sqlite: database),
    );

    final result = await repository.applyRecovered([
      WalletPreferences(walletRef: 'wallet-a', hideOnHome: false),
      WalletPreferences(walletRef: 'missing', autoSweepEnabled: true),
    ]);
    final row = await database.select(database.walletMetadatas).getSingle();

    expect(result, isA<Err<Null, WalletPreferencesFailure>>());
    expect(row.label, 'local');
    expect(row.hideOnHome, isTrue);
    expect(row.autoSweepEnabled, isFalse);
  });

  test('notifies only committed represented-preference changes', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertWalletMetadata(
      database,
      walletRef: 'wallet-a',
      label: 'local',
      hideOnHome: true,
      autoSweepEnabled: false,
    );
    final datasource = WalletMetadataDatasource(sqlite: database);
    final repository = WalletPreferencesRepositoryImpl(datasource);
    var changes = 0;
    final subscription = repository.changes.listen((_) => changes++);
    addTearDown(subscription.cancel);
    final current = (await datasource.fetch('wallet-a'))!;

    await datasource.store(current.copyWith(syncedAt: DateTime.utc(2026)));
    expect(changes, 0);

    await datasource.store(current.copyWith(label: 'changed'));
    expect(changes, 1);

    final recoveryResult = await repository.applyRecovered([
      WalletPreferences(walletRef: 'wallet-a', hideOnHome: false),
    ]);
    expect(recoveryResult, isA<Ok<Null, WalletPreferencesFailure>>());
    expect(changes, 2);
  });
}

Future<void> _insertWalletMetadata(
  SqliteDatabase database, {
  required String walletRef,
  required String label,
  required bool hideOnHome,
  required bool autoSweepEnabled,
}) async {
  await database
      .into(database.walletMetadatas)
      .insert(
        WalletMetadatasCompanion.insert(
          id: walletRef,
          masterFingerprint: 'structural-master',
          xpubFingerprint: 'structural-fingerprint',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: 'structural-xpub',
          externalPublicDescriptor: 'structural-external',
          internalPublicDescriptor: 'structural-internal',
          signer: 'none',
          isDefault: false,
          label: Value(label),
          hideOnHome: Value(hideOnHome),
          autoSweepEnabled: Value(autoSweepEnabled),
        ),
      );
}
