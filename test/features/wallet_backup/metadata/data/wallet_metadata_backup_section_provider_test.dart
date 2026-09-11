import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/data/wallet_metadata_backup_section_provider.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/portable_settings_fixture.dart';

class _Labels extends Mock implements LabelsFacade {}

void main() {
  late _Labels labels;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.addr(address: 'fallback', label: 'fallback'),
    );
  });

  setUp(() => labels = _Labels());

  for (final field in ['label', 'visibility', 'auto-sweep']) {
    for (final duringWrite in [false, true]) {
      test(
        'preserves a $field edit ${duringWrite ? 'during the conditional write' : 'since creation'}',
        () async {
          final initial = WalletPreferences(
            walletRef: 'wallet',
            label: 'Initial',
          );
          final edited = WalletPreferences(
            walletRef: 'wallet',
            label: field == 'label' ? 'Local edit' : 'Initial',
            hideOnHome: field == 'visibility' ? false : null,
            autoSweepEnabled: field == 'auto-sweep' ? true : null,
          );
          var current = duringWrite ? initial : edited;
          when(labels.fetchAllStrict).thenAnswer((_) async => const Ok([]));
          final backup = WalletMetadataBackupImpl(
            labels: labels,
            getFrozenOutpoints: () async => const [],
            restoreFrozenOutpoints: (_) async {},
            getPreferences: () async => Ok([current]),
            applyPreferences: (updates) async {
              if (duringWrite) current = edited;
              final applied = <String>{};
              final conflicted = <String>{};
              for (final update in updates) {
                if (current.hasSameValues(update.expected)) {
                  current = update.recovered;
                  applied.add(current.walletRef);
                } else {
                  conflicted.add(update.expected.walletRef);
                }
              }
              return Ok(
                WalletPreferencesRecoveryApplyResult(
                  appliedWalletRefs: applied,
                  conflictedWalletRefs: conflicted,
                ),
              );
            },
            readPortableSettings: () async => portableSettingsFixture(),
            restorePortableSettings: (_) async {},
            changeStreams: const [],
          );
          addTearDown(backup.dispose);
          final result = await backup.recover(
            snapshot: WalletMetadataSnapshot(
              labels: const [],
              frozenOutpoints: const [],
              walletPreferences: [
                WalletPreferences(
                  walletRef: 'wallet',
                  label: 'Recovered',
                  hideOnHome: true,
                  autoSweepEnabled: false,
                ),
              ],
              settings: portableSettingsFixture(),
            ),
            createdWalletPreferences: [initial],
          );
          expect(result, isA<Ok<bool, WalletMetadataBackupFailure>>());
          expect(
            (result as Ok<bool, WalletMetadataBackupFailure>).value,
            isFalse,
          );
          expect(current, same(edited));
        },
      );
    }
  }

  test('rejects a snapshot whose labels the label store would refuse', () {
    final backup = WalletMetadataBackupImpl(
      labels: labels,
      getFrozenOutpoints: () async => const [],
      restoreFrozenOutpoints: (_) async {},
      getPreferences: () async => const Ok([]),
      applyPreferences: (_) async => Ok(
        WalletPreferencesRecoveryApplyResult(
          appliedWalletRefs: const {},
          conflictedWalletRefs: const {},
        ),
      ),
      readPortableSettings: () async => portableSettingsFixture(),
      restorePortableSettings: (_) async {},
      changeStreams: const [Stream.empty()],
    );
    final snapshot = WalletMetadataSnapshot(
      labels: const [
        WalletMetadataLabel(
          type: LabelType.address,
          reference: 'bc1qexample',
          label: 'Savings',
        ),
      ],
      frozenOutpoints: [
        FrozenWalletOutpoint(walletId: 'wallet-1', txId: 'a' * 64, vout: 0),
      ],
      walletPreferences: [
        WalletPreferences(walletRef: 'wallet-1', label: 'Primary'),
      ],
      settings: portableSettingsFixture(),
    );

    when(() => labels.isValid(any())).thenReturn(true);
    expect(backup.validate(snapshot), isA<Ok>());

    when(() => labels.isValid(any())).thenReturn(false);
    expect(backup.validate(snapshot), isA<Err>());
  });

  test('reads the explicit protected-data categories', () async {
    when(() => labels.fetchAllStrict()).thenAnswer(
      (_) async =>
          Ok([Label.addr(id: 1, address: 'bc1qexample', label: 'Savings')]),
    );
    final backup = WalletMetadataBackupImpl(
      labels: labels,
      getFrozenOutpoints: () async => [
        FrozenWalletOutpoint(walletId: 'wallet-1', txId: 'a' * 64, vout: 0),
      ],
      restoreFrozenOutpoints: (_) async {},
      getPreferences: () async =>
          Ok([WalletPreferences(walletRef: 'wallet-1', label: 'Primary')]),
      applyPreferences: (_) async => Ok(
        WalletPreferencesRecoveryApplyResult(
          appliedWalletRefs: const {},
          conflictedWalletRefs: const {},
        ),
      ),
      readPortableSettings: () async => portableSettingsFixture(),
      restorePortableSettings: (_) async {},
      changeStreams: const [Stream.empty()],
    );

    final result = await backup.localSnapshot();

    expect(
      result,
      isA<Ok<WalletMetadataSnapshot, WalletMetadataBackupFailure>>(),
    );
    final snapshot =
        (result as Ok<WalletMetadataSnapshot, WalletMetadataBackupFailure>)
            .value;
    expect(snapshot.labels, hasLength(1));
    expect(snapshot.frozenOutpoints, hasLength(1));
    expect(snapshot.walletPreferences, hasLength(1));
    await backup.dispose();
  });

  test('restores additively and reports a preserved label conflict', () async {
    final payload = WalletMetadataSnapshot(
      labels: const [
        WalletMetadataLabel(
          type: LabelType.address,
          reference: 'bc1qexample',
          label: 'Savings',
          origin: 'remote',
        ),
      ],
      frozenOutpoints: [
        FrozenWalletOutpoint(walletId: 'wallet-1', txId: 'b' * 64, vout: 1),
      ],
      walletPreferences: [
        WalletPreferences(walletRef: 'wallet-1', hideOnHome: true),
      ],
      settings: portableSettingsFixture(),
    );
    when(() => labels.isValid(any())).thenReturn(true);
    when(() => labels.fetchAllStrict()).thenAnswer(
      (_) async => Ok([
        Label.addr(
          id: 1,
          address: 'bc1qexample',
          label: 'Savings',
          origin: 'local',
        ),
      ]),
    );
    var restoredFreezes = false;
    final backup = WalletMetadataBackupImpl(
      labels: labels,
      getFrozenOutpoints: () async => const [],
      restoreFrozenOutpoints: (_) async => restoredFreezes = true,
      getPreferences: () async =>
          Ok([WalletPreferences(walletRef: 'wallet-1')]),
      applyPreferences: (updates) async => Ok(
        WalletPreferencesRecoveryApplyResult(
          appliedWalletRefs: {
            for (final update in updates) update.recovered.walletRef,
          },
          conflictedWalletRefs: const {},
        ),
      ),
      readPortableSettings: () async => portableSettingsFixture(),
      restorePortableSettings: (_) async {},
      changeStreams: const [Stream.empty()],
    );

    final result = await backup.recover(
      snapshot: payload,
      createdWalletPreferences: [WalletPreferences(walletRef: 'wallet-1')],
    );

    expect((result as Ok<bool, dynamic>).value, isFalse);
    expect(restoredFreezes, isTrue);
    verifyNever(() => labels.store(any()));
    await backup.dispose();
  });

  test(
    'returns typed failures when label recovery cannot read or write',
    () async {
      final emptySnapshot = WalletMetadataSnapshot(
        labels: const [],
        frozenOutpoints: const [],
        walletPreferences: const [],
        settings: portableSettingsFixture(),
      );
      final backup = WalletMetadataBackupImpl(
        labels: labels,
        getFrozenOutpoints: () async => const [],
        restoreFrozenOutpoints: (_) async {},
        getPreferences: () async => const Ok([]),
        applyPreferences: (_) async => Ok(
          WalletPreferencesRecoveryApplyResult(
            appliedWalletRefs: const {},
            conflictedWalletRefs: const {},
          ),
        ),
        readPortableSettings: () async => portableSettingsFixture(),
        restorePortableSettings: (_) async {},
        changeStreams: const [Stream.empty()],
      );
      when(
        () => labels.fetchAllStrict(),
      ).thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

      expect(
        await backup.recover(
          snapshot: emptySnapshot,
          createdWalletPreferences: const [],
        ),
        isA<Err<bool, WalletMetadataBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletMetadataBackupReadFailure>(),
        ),
      );

      final labelSnapshot = WalletMetadataSnapshot(
        labels: const [
          WalletMetadataLabel(
            type: LabelType.address,
            reference: 'bc1qexample',
            label: 'Savings',
          ),
        ],
        frozenOutpoints: const [],
        walletPreferences: const [],
        settings: portableSettingsFixture(),
      );
      when(() => labels.isValid(any())).thenReturn(true);
      when(() => labels.fetchAllStrict()).thenAnswer((_) async => const Ok([]));
      when(
        () => labels.store(any()),
      ).thenAnswer((_) async => const Err(LabelUnexpectedFailure()));

      expect(
        await backup.recover(
          snapshot: labelSnapshot,
          createdWalletPreferences: const [],
        ),
        isA<Err<bool, WalletMetadataBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletMetadataBackupWriteFailure>(),
        ),
      );
      await backup.dispose();
    },
  );
}
