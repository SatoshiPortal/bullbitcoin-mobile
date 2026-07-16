import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_recovered_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_preference_changes_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_preferences_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletPreferencesRepository extends Mock
    implements WalletPreferencesRepository {}

void main() {
  late _MockWalletPreferencesRepository repository;
  late WalletPreferencesMetadataContributor contributor;

  setUp(() {
    repository = _MockWalletPreferencesRepository();
    contributor = WalletPreferencesMetadataContributor(
      GetWalletPreferencesUsecase(repository),
      ApplyRecoveredWalletPreferencesUsecase(repository),
      WatchWalletPreferenceChangesUsecase(repository),
    );
  });

  test('exports only the three approved represented fields', () async {
    const walletRef = 'elwpkh([0f36572d/84h/1h/0h])';
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Ok([
        WalletPreferences(
          walletRef: walletRef,
          label: 'Point of Sale',
          hideOnHome: false,
          autoSweepEnabled: true,
        ),
      ]),
    );

    final record = _requireOk(await contributor.exportRecords()).single;

    expect(record.type, 'wallet.preferences');
    expect(record.version, 1);
    expect(record.scope, {'kind': 'wallet', 'walletRef': walletRef});
    expect(record.recordId, 'preferences');
    expect(record.payload, {
      'walletRef': walletRef,
      'label': 'Point of Sale',
      'hideOnHome': false,
      'autoSweepEnabled': true,
    });
    expect(record.payload.keys, {
      'walletRef',
      'label',
      'hideOnHome',
      'autoSweepEnabled',
    });
  });

  test('omits null fields without replacing them with defaults', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Ok([
        WalletPreferences(walletRef: 'wallet-with-label', label: ''),
        WalletPreferences(walletRef: 'wallet-with-no-preferences'),
      ]),
    );

    final records = _requireOk(await contributor.exportRecords());

    expect(records, hasLength(1));
    expect(records.single.payload, {
      'walletRef': 'wallet-with-label',
      'label': '',
    });
    expect(records.single.payload, isNot(contains('hideOnHome')));
    expect(records.single.payload, isNot(contains('autoSweepEnabled')));
  });

  test('fails the section on duplicate wallet preference identities', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Ok([
        WalletPreferences(walletRef: 'wallet', hideOnHome: true),
        WalletPreferences(walletRef: 'wallet', autoSweepEnabled: true),
      ]),
    );

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
  });

  test('maps a strict repository failure without publishing empty', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => const Err<List<WalletPreferences>, WalletPreferencesFailure>(
        WalletPreferencesStorageFailure(),
      ),
    );

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
    final failure =
        (result as Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>)
            .failure;
    expect(failure, isA<WalletMetadataBackupContributorFailure>());
    expect(
      (failure as WalletMetadataBackupContributorFailure).contributorType,
      'wallet.preferences',
    );
  });

  test('validates represented preference fields without accepting nulls', () {
    final valid = WalletMetadataRecord(
      type: 'wallet.preferences',
      version: 1,
      scope: const {'kind': 'wallet', 'walletRef': 'wallet-a'},
      recordId: 'preferences',
      payload: const {'walletRef': 'wallet-a', 'hideOnHome': false},
    );
    final explicitNull = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: valid.scope,
      recordId: valid.recordId,
      payload: const {'walletRef': 'wallet-a', 'label': null},
    );
    final wrongWallet = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: const {'kind': 'wallet', 'walletRef': 'wallet-b'},
      recordId: valid.recordId,
      payload: valid.payload,
    );

    expect(contributor.validateRecord(valid), isA<WalletMetadataRecordValid>());
    expect(
      (contributor.validateRecord(explicitNull) as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidPayload,
    );
    expect(
      (contributor.validateRecord(wrongWallet) as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidScope,
    );
  });

  test('applies created wallets and reports conflicts and deferrals', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Ok([
        WalletPreferences(
          walletRef: 'created',
          label: 'product default',
          hideOnHome: true,
        ),
        WalletPreferences(walletRef: 'existing', hideOnHome: false),
      ]),
    );
    when(
      () => repository.applyRecovered(any()),
    ).thenAnswer((_) async => const Ok(null));
    final records = [
      _preferenceRecord('created', const {'label': 'restored'}),
      _preferenceRecord('existing', const {'hideOnHome': true}),
      _preferenceRecord('missing', const {'autoSweepEnabled': true}),
    ];

    final result = await contributor.applyIntents(
      intents: records
          .map(
            (record) =>
                (contributor.validateRecord(record)
                        as WalletMetadataRecordValid)
                    .intent,
          )
          .toList(growable: false),
      context: WalletMetadataApplyContext(createdWalletRefs: const {'created'}),
    );
    final summary = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure(
        'expected Ok, got ${failure.runtimeType}',
      ),
    };

    expect(summary.restoredCount, 1);
    expect(summary.preservedLocalConflictCount, 1);
    expect(summary.deferredMissingWalletCount, 1);
    expect(summary.localProjectionMatchesSnapshot, isFalse);
    final applied =
        verify(() => repository.applyRecovered(captureAny())).captured.single
            as List<WalletPreferences>;
    expect(applied, hasLength(1));
    expect(applied.single.walletRef, 'created');
    expect(applied.single.label, 'restored');
    expect(applied.single.hideOnHome, isNull);
  });

  test('allows unrelated local wallet preferences during recovery', () async {
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => Ok([
        WalletPreferences(walletRef: 'created', hideOnHome: false),
        WalletPreferences(walletRef: 'local-only', label: 'Keep me'),
      ]),
    );
    when(
      () => repository.applyRecovered(any()),
    ).thenAnswer((_) async => const Ok(null));
    final record = _preferenceRecord('created', const {'hideOnHome': true});

    final result = await contributor.applyIntents(
      intents: [
        (contributor.validateRecord(record) as WalletMetadataRecordValid)
            .intent,
      ],
      context: WalletMetadataApplyContext(createdWalletRefs: const {'created'}),
    );

    expect(_requireSummary(result).localProjectionMatchesSnapshot, isTrue);
  });
}

WalletMetadataContributorApplySummary _requireSummary(
  Result<WalletMetadataContributorApplySummary, WalletMetadataBackupFailure>
  result,
) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure(
      'expected Ok, got ${failure.runtimeType}',
    ),
  };
}

WalletMetadataRecord _preferenceRecord(
  String walletRef,
  Map<String, Object?> preferences,
) {
  return WalletMetadataRecord(
    type: 'wallet.preferences',
    version: 1,
    scope: {'kind': 'wallet', 'walletRef': walletRef},
    recordId: 'preferences',
    payload: {'walletRef': walletRef, ...preferences},
  );
}

List<WalletMetadataRecord> _requireOk(
  Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure> result,
) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure(
      'expected Ok, got ${failure.runtimeType}',
    ),
  };
}
