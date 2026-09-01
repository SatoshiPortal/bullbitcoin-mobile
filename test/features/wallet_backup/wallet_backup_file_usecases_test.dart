import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/decode_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../keychain_manifest/support/manifest_fixtures.dart';
import 'metadata/support/portable_settings_fixture.dart';
import 'support/canonical_backup_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('file validation', () {
    test('an export cannot contain zero bytes', () {
      expect(
        () => WalletBackupExport(suggestedFilename: 'backup.json', bytes: []),
        throwsArgumentError,
      );
    });

    test(
      'decode rejects empty, oversized, and malformed UTF-8 input',
      () async {
        final decoder = DecodeWalletBackupFileUsecase(
          () async => Ok(_key),
          _Encryption(),
        );

        expect(
          await decoder.execute(Uint8List(0)),
          isA<Err>().having(
            (value) => value.failure,
            'failure',
            isA<WalletBackupInvalidEnvelopeFailure>(),
          ),
        );
        expect(
          await decoder.execute(
            Uint8List(DecodeWalletBackupFileUsecase.maximumFileBytes + 1),
          ),
          isA<Err>().having(
            (value) => value.failure,
            'failure',
            isA<WalletBackupTooLargeFailure>(),
          ),
        );
        expect(
          await decoder.execute(Uint8List.fromList([0xff])),
          isA<Err>().having(
            (value) => value.failure,
            'failure',
            isA<WalletBackupInvalidEnvelopeFailure>(),
          ),
        );
      },
    );

    test(
      'decode accepts conventional whitespace before plaintext JSON',
      () async {
        final decoder = DecodeWalletBackupFileUsecase(
          () async => Ok(_key),
          const _Encryption(acceptPlaintext: true),
        );

        expect(
          await decoder.execute(Uint8List.fromList(utf8.encode(' \n{"v":1}'))),
          isA<Ok<WalletBackupSnapshot, WalletBackupFailure>>(),
        );
      },
    );
  });

  group('comparison', () {
    test(
      'disabled automatic backup still compares an existing server backup',
      () async {
        var fetches = 0;
        final usecase = _comparison(
          state: _state(enabled: false),
          fetchRemote: () async {
            fetches++;
            return Ok(_head(_serverCiphertext));
          },
          server: _serverSnapshot(),
        );

        final result = await usecase.execute(Uint8List.fromList([1]));

        expect(result, isA<Ok>());
        final comparison = (result as Ok).value as WalletBackupImportComparison;
        expect(comparison.situation, WalletBackupImportSituation.different);
        expect(comparison.server, isNotNull);
        expect(fetches, 1);
      },
    );

    test(
      'disabled automatic backup reports no server backup accurately',
      () async {
        final usecase = _comparison(
          state: _state(enabled: false),
          fetchRemote: () async =>
              Ok(WalletBackupRemoteHead.absent(generation: 0, etag: null)),
        );

        final result = await usecase.execute(Uint8List.fromList([1]));

        final comparison = (result as Ok).value as WalletBackupImportComparison;
        expect(
          comparison.situation,
          WalletBackupImportSituation.automaticBackupDisabled,
        );
        expect(comparison.server, isNull);
      },
    );

    test('reports exact manifest, definition, and metadata counts', () async {
      final backup = _fileSnapshot(
        definitions: [
          _definition('one'),
          _definition('two', fingerprint: '76241f88'),
        ],
        metadata: _metadata(labels: 3, frozenOutpoints: 4, preferences: 5),
      );
      final usecase = _comparison(
        file: backup,
        state: _state(enabled: true),
        fetchRemote: () async =>
            const Err(WalletBackupRemoteUnavailableFailure()),
      );

      final result = await usecase.execute(Uint8List.fromList([1]));
      final summary =
          ((result as Ok).value as WalletBackupImportComparison).file;

      expect(summary.createdAt, 9);
      expect(summary.walletCount, 1);
      expect(summary.nostrIdentityCount, 1);
      expect(summary.externalWalletCount, 2);
      expect(summary.labelCount, 3);
      expect(summary.frozenOutpointCount, 4);
      expect(summary.walletPreferenceCount, 5);
    });

    test('a rejected file fails comparison instead of estimating', () async {
      final usecase = CompareWalletBackupFileUsecase(
        (_) async => const Err(WalletBackupManifestFailure()),
        () async => Ok(_state(enabled: false)),
        () async => throw StateError('server must not be called'),
        (_) async => const Ok(null),
        _codec.differences,
      );

      expect(
        await usecase.execute(Uint8List.fromList([1])),
        isA<Err>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupManifestFailure>(),
        ),
      );
    });

    test('does not disguise authentication failures as offline', () async {
      final usecase = _comparison(
        state: _state(enabled: true),
        fetchRemote: () async => const Err(WalletBackupSigningFailure()),
      );

      expect(
        await usecase.execute(Uint8List.fromList([1])),
        isA<Err>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupSigningFailure>(),
        ),
      );
    });

    test('does not disguise an invalid remote response as offline', () async {
      final usecase = _comparison(
        state: _state(enabled: true),
        fetchRemote: () async => const Err(WalletBackupInvalidRemoteFailure()),
      );

      expect(
        await usecase.execute(Uint8List.fromList([1])),
        isA<Err>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupInvalidRemoteFailure>(),
        ),
      );
    });

    test(
      'does not disguise an unsupported server snapshot as offline',
      () async {
        final usecase = _comparison(
          state: _state(enabled: true),
          fetchRemote: () async => Ok(_head(_serverCiphertext)),
          fetchImport: (_) async =>
              const Err(WalletBackupUnsupportedEnvelopeVersionFailure(2)),
        );

        expect(
          await usecase.execute(Uint8List.fromList([1])),
          isA<Err>().having(
            (value) => value.failure,
            'failure',
            isA<WalletBackupUnsupportedEnvelopeVersionFailure>(),
          ),
        );
      },
    );

    test('captures the exact server ciphertext used for its summary', () async {
      var remoteFetches = 0;
      final usecase = _comparison(
        state: _state(enabled: true),
        fetchRemote: () async {
          remoteFetches++;
          return Ok(_head(_serverCiphertext));
        },
        server: _serverSnapshot(),
      );

      final result = await usecase.execute(Uint8List.fromList([1]));
      final comparison = (result as Ok).value as WalletBackupImportComparison;
      final firstCopy = comparison.copyServerCiphertextBytes()!;
      firstCopy[0] = 0;

      expect(remoteFetches, 1);
      expect(
        utf8.decode(comparison.copyServerCiphertextBytes()!),
        _serverCiphertext.value,
      );
    });

    test(
      'detects canonical manifest changes when identities still match',
      () async {
        final usecase = _comparison(
          state: _state(enabled: true),
          fetchRemote: () async => Ok(_head(_serverCiphertext)),
          server: _fileSnapshot(
            recoveryManifest: manifest(
              generatedAt: 9,
              entries: [
                walletManifestEntry(updatedAt: 7),
                nostrManifestEntry(purpose: 'Renamed identity'),
              ],
            ),
          ),
        );

        final result = await usecase.execute(Uint8List.fromList([1]));
        final comparison = (result as Ok).value as WalletBackupImportComparison;

        expect(comparison.situation, WalletBackupImportSituation.different);
        expect(
          comparison.differences,
          contains(WalletBackupDifference.walletManifest),
        );
      },
    );

    test('ignores the manifest generation time when content matches', () async {
      final usecase = _comparison(
        file: _fileSnapshot(
          recoveryManifest: manifest(generatedAt: 9),
          definitions: [_definition('one')],
          metadata: _metadata(labels: 1),
        ),
        state: _state(enabled: true),
        fetchRemote: () async => Ok(_head(_serverCiphertext)),
        server: _fileSnapshot(
          recoveryManifest: manifest(generatedAt: 99),
          definitions: [_definition('one')],
          metadata: _metadata(labels: 1),
        ),
      );

      final result = await usecase.execute(Uint8List.fromList([1]));
      final comparison = (result as Ok).value as WalletBackupImportComparison;

      expect(comparison.situation, WalletBackupImportSituation.same);
      expect(comparison.differences, isEmpty);
    });

    test('still reports same-count protected content changes', () async {
      final usecase = _comparison(
        file: _fileSnapshot(metadata: _metadata(labels: 1, labelText: 'first')),
        state: _state(enabled: true),
        fetchRemote: () async => Ok(_head(_serverCiphertext)),
        server: _fileSnapshot(
          metadata: _metadata(labels: 1, labelText: 'second'),
        ),
      );

      final result = await usecase.execute(Uint8List.fromList([1]));
      final comparison = (result as Ok).value as WalletBackupImportComparison;

      expect(comparison.situation, WalletBackupImportSituation.different);
      expect(
        comparison.differences,
        contains(WalletBackupDifference.protectedData),
      );
    });
  });

  group('compared recovery', () {
    test('disabled comparison applies locally without publishing', () async {
      var stores = 0;
      var pending = 0;
      final usecase = _recovery(
        state: _state(enabled: false),
        storeSelected: ({required selected, required current}) async {
          stores++;
          return const Ok(null);
        },
        markPending: () async {
          pending++;
          return const Ok(null);
        },
      );

      final result = await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: _comparisonValue(
          WalletBackupImportSituation.automaticBackupDisabled,
        ),
        source: WalletBackupImportSource.file,
      );

      expect(result.status, WalletBackupRecoveryStatus.restored);
      expect(stores, 0);
      expect(pending, 0);
    });

    test(
      'disabled automatic backup applies the file without server access',
      () async {
        var applies = 0;
        var stores = 0;
        final usecase = _recovery(
          state: _state(enabled: false),
          fetchRemote: () async =>
              throw StateError('server must not be called'),
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          storeSelected: ({required selected, required current}) async {
            stores++;
            return const Ok(null);
          },
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.different,
            withServer: true,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.restored);
        expect(applies, 1);
        expect(stores, 0);
      },
    );

    test(
      'unavailable server applies the file and schedules reconciliation',
      () async {
        var decodes = 0;
        var applies = 0;
        var stores = 0;
        var unblocks = 0;
        var pending = 0;
        final usecase = _recovery(
          decode: (_) async {
            decodes++;
            return Ok(_fileSnapshot());
          },
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          fetchRemote: () async =>
              const Err(WalletBackupRemoteUnavailableFailure()),
          storeSelected: ({required selected, required current}) async {
            stores++;
            return const Ok(null);
          },
          setBlocked: (blocked) async {
            if (!blocked) unblocks++;
            return const Ok(null);
          },
          markPending: () async {
            pending++;
            return const Ok(null);
          },
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.serverUnavailable,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.restored);
        expect(decodes, 1);
        expect(applies, 1);
        expect(stores, 0);
        expect(unblocks, 0);
        expect(pending, 1);
      },
    );

    test(
      'new remote after comparison forces a new choice before apply',
      () async {
        var applies = 0;
        final usecase = _recovery(
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          fetchRemote: () async => Ok(_head(_serverCiphertext)),
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.serverUnavailable,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.comparisonStale);
        expect(applies, 0);
      },
    );

    test('store failure persists reconciliation', () async {
      var pending = 0;
      final usecase = _recovery(
        storeSelected: ({required selected, required current}) async =>
            const Err(WalletBackupRemoteUnavailableFailure()),
        markPending: () async {
          pending++;
          return const Ok(null);
        },
      );

      final result = await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: _comparisonValue(
          WalletBackupImportSituation.noServerBackup,
        ),
        source: WalletBackupImportSource.file,
      );

      expect(result.status, WalletBackupRecoveryStatus.restored);
      expect(pending, 1);
    });

    test('pending persistence failure is a local failure', () async {
      final usecase = _recovery(
        storeSelected: ({required selected, required current}) async =>
            const Err(WalletBackupRemoteUnavailableFailure()),
        markPending: () async => const Err(WalletBackupStorageFailure()),
      );

      final result = await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: _comparisonValue(
          WalletBackupImportSituation.noServerBackup,
        ),
        source: WalletBackupImportSource.file,
      );

      expect(result.status, WalletBackupRecoveryStatus.localFailure);
    });

    test(
      'server selection decodes captured bytes after freshness checks',
      () async {
        Uint8List? decoded;
        var stores = 0;
        var pending = 0;
        final comparison = _comparisonValue(
          WalletBackupImportSituation.same,
          withServer: true,
        );
        final usecase = _recovery(
          decode: (bytes) async {
            decoded = Uint8List.fromList(bytes);
            return Ok(_serverSnapshot());
          },
          storeSelected: ({required selected, required current}) async {
            stores++;
            return const Ok(null);
          },
          markPending: () async {
            pending++;
            return const Ok(null);
          },
          fetchRemote: () async => Ok(_head(_serverCiphertext)),
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([9]),
          comparison: comparison,
          source: WalletBackupImportSource.server,
        );

        expect(result.status, WalletBackupRecoveryStatus.restored);
        expect(utf8.decode(decoded!), _serverCiphertext.value);
        expect(stores, 0);
        expect(pending, 0);
      },
    );

    test('changed remote head rejects the file before applying', () async {
      var applies = 0;
      var stores = 0;
      final comparison = WalletBackupImportComparison(
        situation: WalletBackupImportSituation.noServerBackup,
        file: _summary,
        server: null,
        comparedServerGeneration: 1,
        comparedServerEtag: _hash,
        differences: const {},
      );
      final usecase = _recovery(
        apply: ({required snapshot, deadline}) async {
          applies++;
          return const WalletBackupRecoveryResult(
            status: WalletBackupRecoveryStatus.restored,
          );
        },
        fetchRemote: () async =>
            Ok(WalletBackupRemoteHead.absent(generation: 2, etag: _otherHash)),
        storeSelected: ({required selected, required current}) async {
          stores++;
          return const Ok(null);
        },
      );

      final result = await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: comparison,
        source: WalletBackupImportSource.file,
      );

      expect(result.status, WalletBackupRecoveryStatus.comparisonStale);
      expect(applies, 0);
      expect(stores, 0);
    });

    test(
      'changed remote head rejects the server choice before applying',
      () async {
        var applies = 0;
        final usecase = _recovery(
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          fetchRemote: () async => Ok(
            WalletBackupRemoteHead.absent(generation: 2, etag: _otherHash),
          ),
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.different,
            withServer: true,
          ),
          source: WalletBackupImportSource.server,
        );

        expect(result.status, WalletBackupRecoveryStatus.comparisonStale);
        expect(applies, 0);
      },
    );

    test(
      'freshness authentication failure is not treated as offline',
      () async {
        var applies = 0;
        final usecase = _recovery(
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          fetchRemote: () async => const Err(WalletBackupSigningFailure()),
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.different,
            withServer: true,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.localFailure);
        expect(applies, 0);
      },
    );

    test(
      'unsupported selected file fails before the runner is asked for work',
      () async {
        var applies = 0;
        var outcomes = 0;
        final usecase = _recovery(
          decode: (_) async =>
              const Err(WalletBackupUnsupportedEnvelopeVersionFailure(2)),
          apply: ({required snapshot, deadline}) async {
            applies++;
            return const WalletBackupRecoveryResult(
              status: WalletBackupRecoveryStatus.restored,
            );
          },
          saveOutcome: (_) async {
            outcomes++;
            return const Ok(null);
          },
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.noServerBackup,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.newerVersion);
        expect(applies, 0);
        expect(outcomes, 0);
      },
    );

    test('file choice CAS-publishes while recovery remains fenced', () async {
      WalletBackupSnapshot? stored;
      var unblockedAfterStore = false;
      final usecase = _recovery(
        fetchRemote: () async => Ok(_head(_serverCiphertext)),
        storeSelected: ({required selected, required current}) async {
          stored = selected;
          return const Ok(null);
        },
        setBlocked: (blocked) async {
          if (!blocked) unblockedAfterStore = stored != null;
          return const Ok(null);
        },
      );

      final result = await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: _comparisonValue(
          WalletBackupImportSituation.different,
          withServer: true,
        ),
        source: WalletBackupImportSource.file,
      );

      expect(result.status, WalletBackupRecoveryStatus.restored);
      expect(
        stored?.recoveryManifest.wallets.map((wallet) => wallet.walletId),
        ['wallet-1'],
      );
      expect(stored?.createdAt, 9);
      expect(unblockedAfterStore, isTrue);
    });

    test(
      'CAS conflict after local apply stays fenced and reports stale',
      () async {
        var pending = 0;
        var unblocks = 0;
        final savedOutcomes = <WalletBackupRecoveryStatus>[];
        final usecase = _recovery(
          fetchRemote: () async => Ok(_head(_serverCiphertext)),
          storeSelected: ({required selected, required current}) async =>
              const Err(WalletBackupHeadConflictFailure()),
          markPending: () async {
            pending++;
            return const Ok(null);
          },
          setBlocked: (blocked) async {
            if (!blocked) unblocks++;
            return const Ok(null);
          },
          saveOutcome: (status) async {
            savedOutcomes.add(status);
            return const Ok(null);
          },
        );

        final result = await usecase.execute(
          fileBytes: Uint8List.fromList([1]),
          comparison: _comparisonValue(
            WalletBackupImportSituation.different,
            withServer: true,
          ),
          source: WalletBackupImportSource.file,
        );

        expect(result.status, WalletBackupRecoveryStatus.comparisonStale);
        expect(pending, 1);
        expect(unblocks, 0);
        expect(savedOutcomes, [WalletBackupRecoveryStatus.comparisonStale]);
      },
    );

    test('a Nostr-only import still schedules publication', () async {
      var stores = 0;
      final usecase = _recovery(
        decode: (_) async => Ok(
          _fileSnapshot(
            recoveryManifest: manifest(entries: [nostrManifestEntry()]),
          ),
        ),
        storeSelected: ({required selected, required current}) async {
          stores++;
          return const Ok(null);
        },
      );

      await usecase.execute(
        fileBytes: Uint8List.fromList([1]),
        comparison: _comparisonValue(
          WalletBackupImportSituation.noServerBackup,
        ),
        source: WalletBackupImportSource.file,
      );

      expect(stores, 1);
    });
  });
}

CompareWalletBackupFileUsecase _comparison({
  WalletBackupSnapshot? file,
  required WalletBackupState state,
  required Future<Result<WalletBackupRemoteHead, WalletBackupFailure>>
  Function()
  fetchRemote,
  WalletBackupSnapshot? server,
  Future<Result<WalletBackupSnapshot?, WalletBackupFailure>> Function(
    WalletBackupRemoteHead,
  )?
  fetchImport,
}) => CompareWalletBackupFileUsecase(
  (_) async => Ok(file ?? _fileSnapshot()),
  () async => Ok(state),
  fetchRemote,
  fetchImport ?? (_) async => Ok(server),
  _codec.differences,
);

RecoverWalletBackupFileUsecase _recovery({
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> Function(Uint8List)?
  decode,
  ApplyWalletBackupFileImport? apply,
  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> Function()?
  fetchRemote,
  StoreSelectedWalletBackup? storeSelected,
  Future<Result<void, WalletBackupFailure>> Function(
    WalletBackupRecoveryStatus,
  )?
  saveOutcome,
  Future<Result<void, WalletBackupFailure>> Function()? markPending,
  Future<Result<void, WalletBackupFailure>> Function(bool)? setBlocked,
  WalletBackupState? state,
}) => RecoverWalletBackupFileUsecase(
  decode ?? (_) async => Ok(_fileSnapshot()),
  apply ??
      ({required snapshot, deadline}) async => const WalletBackupRecoveryResult(
        status: WalletBackupRecoveryStatus.restored,
        restoredCount: 1,
      ),
  _settle(
    markPending: markPending ?? () async => const Ok(null),
    setBlocked: setBlocked ?? (_) async => const Ok(null),
    saveOutcome: saveOutcome ?? (_) async => const Ok(null),
  ),
  () async => Ok(state ?? _state(enabled: true)),
  fetchRemote ??
      () async => Ok(WalletBackupRemoteHead.absent(generation: 0, etag: null)),
  storeSelected ??
      ({required selected, required current}) async => const Ok(null),
);

/// The file path used to raise and lower two separate flags; it now hands one
/// fence value to the shared apply owner. These tests still describe the same
/// three observable moves, so the fence is translated back into them here.
SettleWalletBackupFence _settle({
  required Future<Result<void, WalletBackupFailure>> Function() markPending,
  required Future<Result<void, WalletBackupFailure>> Function(bool) setBlocked,
  required Future<Result<void, WalletBackupFailure>> Function(
    WalletBackupRecoveryStatus,
  )
  saveOutcome,
}) => (result, {required fence}) async {
  final fenceWrite = switch (fence) {
    WalletBackupRecoveryState.needsAttention => await markPending(),
    WalletBackupRecoveryState.idle => await setBlocked(false),
    _ => const Ok<void, WalletBackupFailure>(null),
  };
  if (fenceWrite case Err()) return _localFailure(result);
  if (await saveOutcome(result.status) case Err()) {
    return _localFailure(result);
  }
  return result;
};

WalletBackupRecoveryResult _localFailure(WalletBackupRecoveryResult result) =>
    WalletBackupRecoveryResult(
      status: WalletBackupRecoveryStatus.localFailure,
      restoredCount: result.restoredCount,
      failedCount: result.failedCount,
    );

WalletBackupImportComparison _comparisonValue(
  WalletBackupImportSituation situation, {
  bool withServer = false,
}) => WalletBackupImportComparison(
  situation: situation,
  file: _summary,
  server: withServer ? _summary : null,
  comparedServerGeneration: withServer
      ? 1
      : situation == WalletBackupImportSituation.noServerBackup
      ? 0
      : null,
  comparedServerEtag: withServer ? _hash : null,
  serverCiphertextBytes: withServer
      ? Uint8List.fromList(utf8.encode(_serverCiphertext.value))
      : null,
  differences: const {},
);

final _codec = canonicalCodec();

WalletBackupSnapshot _fileSnapshot({
  KeychainManifest? recoveryManifest,
  List<WalletDefinition> definitions = const [],
  WalletMetadataSnapshot? metadata,
}) => WalletBackupSnapshot(
  parentFingerprint: manifestFingerprint,
  createdAt: 9,
  recoveryManifest:
      recoveryManifest ??
      manifest(
        generatedAt: 9,
        entries: [walletManifestEntry(), nostrManifestEntry()],
      ),
  externalWalletDefinitions: definitions,
  metadata: metadata,
);

WalletBackupSnapshot _serverSnapshot() => WalletBackupSnapshot(
  parentFingerprint: manifestFingerprint,
  createdAt: 10,
  recoveryManifest: manifest(
    generatedAt: 10,
    entries: [walletManifestEntry(walletId: 'server-wallet')],
  ),
);

WalletDefinition _definition(
  String walletRef, {
  String fingerprint = '86241f88',
}) => WalletDefinition(
  walletRef: walletRef,
  network: Network.bitcoinMainnet,
  descriptor: canonicalExternalDescriptor.replaceFirst('86241f88', fingerprint),
  provenance: WalletProvenance.watchOnly,
);

WalletMetadataSnapshot _metadata({
  int labels = 0,
  int frozenOutpoints = 0,
  int preferences = 0,
  String labelText = 'label',
}) => WalletMetadataSnapshot(
  labels: [
    for (var index = 0; index < labels; index++)
      WalletMetadataLabel(
        type: LabelType.address,
        reference: 'bc1q$index',
        label: '$labelText-$index',
      ),
  ],
  frozenOutpoints: [
    for (var index = 0; index < frozenOutpoints; index++)
      FrozenWalletOutpoint(
        walletId: 'wallet-1',
        txId: '$index'.padLeft(64, 'a'),
        vout: index,
      ),
  ],
  walletPreferences: [
    for (var index = 0; index < preferences; index++)
      WalletPreferences(walletRef: 'wallet-$index', hideOnHome: true),
  ],
  settings: portableSettingsFixture(),
);

WalletBackupState _state({required bool enabled}) => WalletBackupState(
  enabled: enabled,
  localRevision: 0,
  uploadedRevision: 0,
  lastSucceededAt: null,
  unsupportedVersion: null,
  customServerUrl: null,
);

WalletBackupRemoteHead _head(WalletBackupCiphertext ciphertext) =>
    WalletBackupRemoteHead.present(
      generation: 1,
      etag: _hash,
      ciphertext: ciphertext,
      ciphertextSha256: _hash,
    );

final _serverCiphertext = WalletBackupCiphertext(
  base64.encode(List.filled(64, 7)),
);

const _summary = WalletBackupSnapshotSummary(
  createdAt: 1,
  walletCount: 1,
  nostrIdentityCount: 0,
  externalWalletCount: 0,
  labelCount: 0,
  frozenOutpointCount: 0,
  walletPreferenceCount: 0,
);

final _key = (
  parentFingerprint: '73c5da0a',
  encryptionKey: WalletBackupEncryptionKey('11' * 32),
);

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final class _Encryption implements WalletBackupEncryptionRepository {
  final bool acceptPlaintext;

  const _Encryption({this.acceptPlaintext = false});

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decodeCanonical({
    required Uint8List bytes,
    required String expectedParentFingerprint,
  }) => acceptPlaintext
      ? Ok(_fileSnapshot())
      : const Err(WalletBackupInvalidEnvelopeFailure());

  @override
  Result<WalletBackupSnapshot, WalletBackupFailure> decrypt({
    required WalletBackupCiphertext ciphertext,
    required WalletBackupEncryptionKey key,
    required String expectedParentFingerprint,
  }) => const Err(WalletBackupInvalidEnvelopeFailure());

  @override
  Result<Uint8List, WalletBackupFailure> encodeCanonical(
    WalletBackupSnapshot envelope,
  ) => throw UnimplementedError();

  @override
  Result<WalletBackupCiphertext, WalletBackupFailure> encrypt({
    required WalletBackupSnapshot envelope,
    required WalletBackupEncryptionKey key,
  }) => throw UnimplementedError();
}
