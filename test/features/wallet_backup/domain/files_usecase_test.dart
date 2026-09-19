import 'dart:async';
import 'dart:convert';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/bullvault_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_snapshot_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../backup_snapshot_fixture.dart';

class _Identity extends Mock implements NostrIdentityFacade {}

class _State extends Mock implements WalletBackupStateRepository {}

class _Snapshots extends Mock implements WalletBackupSnapshotRepository {}

class _Files extends Mock implements WalletBackupFileRepository {}

class _Catalog extends Mock implements KeychainManifestFacade {}

class _Wallets extends Mock implements WalletInventoryBackupRepository {}

class _Vaults extends Mock implements BullVaultBackupRepository {}

class _Metadata extends Mock implements WalletMetadataBackupRepository {}

class _VaultCodec extends Mock implements BullVaultFacade {}

class _Remote extends Mock implements WalletBackupRemoteRepository {}

T value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;
void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final snapshot = backupSnapshotFixture(credential, populated: false);
  final codec = WalletBackupCodecRepositoryImpl(_VaultCodec());
  late _Identity identity;
  late _State state;
  late _Snapshots snapshots;
  late _Files files;
  late _Catalog catalog;
  late _Metadata metadata;
  late StreamController<void> changes;
  late ExportWalletBackupFileUsecase export;
  late DecodeWalletBackupFileUsecase decode;
  late RecoverWalletBackupFileUsecase recover;
  var incomplete = false, applied = 0;
  setUpAll(() {
    registerFallbackValue(snapshot.manifest);
    registerFallbackValue(snapshot.metadata);
    registerFallbackValue(WalletBackupFileFormat.encrypted);
  });
  setUp(() {
    identity = _Identity();
    state = _State();
    snapshots = _Snapshots();
    files = _Files();
    catalog = _Catalog();
    metadata = _Metadata();
    final wallets = _Wallets();
    final vaults = _Vaults();
    incomplete = false;
    applied = 0;
    changes = StreamController<void>.broadcast(sync: true);
    when(identity.resolve).thenAnswer((_) async => Ok(credential));
    when(
      () => identity.fromWords('wrong'),
    ).thenReturn(const Err(InvalidDataRecoveryWords()));
    when(
      () => identity.fromWords(backupFixtureWords),
    ).thenReturn(Ok(credential));
    when(() => state.getControl()).thenAnswer(
      (_) async => Ok(
        WalletBackupControl(enabled: false, recoveryIncomplete: incomplete),
      ),
    );
    when(() => state.setRecoveryIncomplete(any())).thenAnswer((call) async {
      incomplete = call.positionalArguments.single as bool;
      return const Ok(null);
    });
    when(() => snapshots.changes).thenAnswer((_) => changes.stream);
    when(
      () => snapshots.capture(credential),
    ).thenAnswer((_) async => Ok(snapshot));
    when(
      () => files.save(any(), format: any(named: 'format')),
    ).thenAnswer((_) async => const Ok(true));
    when(() => catalog.restorePublicRecords(any())).thenAnswer((_) async {
      expect(incomplete, isTrue);
      applied++;
      return const Ok(null);
    });
    when(() => wallets.restore([])).thenAnswer(
      (_) async => Ok(
        WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
      ),
    );
    when(() => vaults.restore([], [])).thenAnswer(
      (_) async => Ok(
        WalletInventoryRecovery(walletReferences: {}, failedReferences: []),
      ),
    );
    when(
      () => metadata.apply(any(), {}),
    ).thenAnswer((_) async => const Ok(null));
    final operations = WalletBackupOperationQueue();
    export = ExportWalletBackupFileUsecase(
      operations: operations,
      identity: identity,
      state: state,
      snapshots: snapshots,
      codec: codec,
      files: files,
    );
    decode = DecodeWalletBackupFileUsecase(identity: identity, codec: codec);
    final apply = ApplyWalletBackupSnapshotUsecase(
      state: state,
      codec: codec,
      catalog: catalog,
      wallets: wallets,
      vaults: vaults,
      metadata: metadata,
    );
    final remote = _Remote();
    recover = RecoverWalletBackupFileUsecase(
      operations: operations,
      decode: decode,
      identity: identity,
      state: state,
      remote: remote,
      codec: codec,
      apply: apply,
      recoverRemote: RecoverWalletBackupUsecase(
        operations: operations,
        identity: identity,
        state: state,
        remote: remote,
        codec: codec,
        apply: apply,
      ),
    );
  });
  tearDown(() => changes.close());
  String encoded(WalletBackupFileFormat format) =>
      value(codec.encodeFile(snapshot, credential, format: format));

  WalletBackupFileComparison comparison() => WalletBackupFileComparison(
    file: value(
      codec.decodeFile(
        encoded(WalletBackupFileFormat.readable),
        credential: credential,
      ),
    ),
    server: null,
    serverFailure: const WalletBackupNetworkFailure(),
    automaticBackupEnabled: false,
  );

  test(
    'readable export needs confirmation before resolving any credential',
    () async {
      expect(await export.execute(WalletBackupFileFormat.readable), isA<Err>());
      verifyZeroInteractions(identity);
      verifyZeroInteractions(snapshots);
      verifyZeroInteractions(files);
    },
  );
  test(
    'encrypted and confirmed readable export save the same snapshot and preserve cancellation',
    () async {
      for (final format in WalletBackupFileFormat.values) {
        expect(value(await export.execute(format, confirmed: true)), isTrue);
      }
      final calls = verify(
        () => files.save(captureAny(), format: any(named: 'format')),
      ).captured;
      for (final source in calls) {
        expect(
          codec.decodeFile(source as String, credential: credential),
          isA<Ok>(),
        );
      }
      when(
        () => files.save(any(), format: any(named: 'format')),
      ).thenAnswer((_) async => const Ok(false));
      expect(
        value(await export.execute(WalletBackupFileFormat.encrypted)),
        isFalse,
      );
      expect(incomplete, isFalse);
      expect(applied, 0);
    },
  );
  test(
    'incomplete recovery and capture races cannot be exported as a complete file',
    () async {
      incomplete = true;
      expect(
        await export.execute(WalletBackupFileFormat.encrypted),
        isA<Err>(),
      );
      verifyZeroInteractions(files);
      incomplete = false;
      when(() => snapshots.capture(credential)).thenAnswer((_) async {
        changes.add(null);
        return Ok(snapshot);
      });
      expect(
        await export.execute(WalletBackupFileFormat.encrypted),
        isA<Err>(),
      );
      verifyZeroInteractions(files);
    },
  );
  test(
    'decode is read-only and readable inspection can work without a seed',
    () async {
      final decoded = value(
        await decode.execute(encoded(WalletBackupFileFormat.readable)),
      );
      expect(decoded.format, WalletBackupFileFormat.readable);
      expect(applied, 0);
      expect(incomplete, isFalse);
      when(
        identity.resolve,
      ).thenAnswer((_) async => const Err(BackupCredentialUnavailable()));
      expect(
        await decode.execute(encoded(WalletBackupFileFormat.readable)),
        isA<Ok>(),
      );
      expect(
        await decode.execute(encoded(WalletBackupFileFormat.encrypted)),
        isA<Err>(),
      );
    },
  );
  test('wrong words and refused confirmation never apply a file', () async {
    final source = encoded(WalletBackupFileFormat.encrypted);
    expect(
      await recover.execute(
        source,
        comparison: comparison(),
        source: WalletBackupImportSource.file,
        confirmed: false,
      ),
      isA<Err>(),
    );
    verifyZeroInteractions(identity);
    expect(
      await recover.execute(
        source,
        comparison: comparison(),
        source: WalletBackupImportSource.file,
        words: 'wrong',
        confirmed: true,
      ),
      isA<Err>(),
    );
    expect(applied, 0);
    expect(incomplete, isFalse);
  });
  test(
    'confirmed file restore uses the common fence and reports partial failure',
    () async {
      final source = encoded(WalletBackupFileFormat.encrypted);
      when(
        () => metadata.apply(any(), {}),
      ).thenAnswer((_) async => const Err(WalletBackupStorageFailure()));
      final partial = value(
        await recover.execute(
          source,
          comparison: comparison(),
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(partial.complete, isFalse);
      expect(incomplete, isTrue);
      expect(applied, 1);
      when(
        () => metadata.apply(any(), {}),
      ).thenAnswer((_) async => const Ok(null));
      final retried = value(
        await recover.execute(
          source,
          comparison: comparison(),
          source: WalletBackupImportSource.file,
          confirmed: true,
        ),
      );
      expect(retried.complete, isTrue);
      expect(incomplete, isFalse);
      verifyNever(() => state.setEnabled(any()));
    },
  );
  test('tampering after inspection is rechecked before application', () async {
    final source = encoded(WalletBackupFileFormat.readable);
    expect(await decode.execute(source), isA<Ok>());
    final model = jsonDecode(source) as Map<String, dynamic>;
    model['signature'] = '0' * 128;
    expect(
      await recover.execute(
        jsonEncode(model),
        comparison: comparison(),
        source: WalletBackupImportSource.file,
        confirmed: true,
      ),
      isA<Err>(),
    );
    expect(applied, 0);
    expect(incomplete, isFalse);
  });
}
