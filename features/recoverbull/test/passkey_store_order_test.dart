import 'dart:async';
import 'dart:typed_data';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/passkey_password_deriver.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_observation.dart';
import 'package:bull_recoverbull/src/domain/entities/backup_monitoring.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_key_fetch.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/passkey_secret_port.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_usecase.dart';
import 'package:file_system/file_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.regtest,
  );
  final settings = BackupSettings(
    server: Uri.parse(
      'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion',
    ),
    permissionGranted: true,
    monitoringEnabled: false,
    generation: 1,
  );
  final passkey = VaultPasskey(
    rpId: 'passkey.example.com',
    credentialId: [1, 2, 3],
    prfSalt: List.filled(32, 5),
  );
  late List<String> events;
  late _Server server;
  late _Prf prf;
  late _Files files;
  late _Metadata metadata;
  late CreateAndStoreVaultUsecase usecase;

  setUp(() {
    events = [];
    server = _Server(events);
    prf = _Prf(events);
    files = _Files(events);
    metadata = _Metadata(events, settings);
    final monitoring = _Monitoring(events);
    final fetch = FetchVaultKeyUsecase(monitoring);
    usecase = CreateAndStoreVaultUsecase(
      CreateVaultUsecase(_Vaults(events), _Wallets(context)),
      SaveVaultUsecase(files, _Drive()),
      metadata,
      monitoring,
      fetch,
    );
  });

  Future<Result<VaultCompletion, RecoverBullFailure>> create() =>
      usecase.executePasskey(
        settings: settings,
        server: server,
        provider: VaultProvider.customLocation,
        passkey: passkey,
        secrets: prf,
        passwords: const PasskeyPasswordDeriver(),
      );

  test('confirms server key before publishing and erases PRF', () async {
    expect(await create(), isA<Ok<VaultCompletion, RecoverBullFailure>>());
    expect(events, [
      'prf',
      'seal',
      'register',
      'settings',
      'store',
      'settings',
      'begin',
      'fetch',
      'complete',
      'settings',
      'save',
      'markStored',
    ]);
    expect(prf.bytes, everyElement(0));
  });

  test('ambiguous store failure never publishes', () async {
    server.failStore = true;
    expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(events, isNot(contains('save')));
    expect(prf.bytes, everyElement(0));
  });

  test('failed confirmation never publishes', () async {
    server.failFetch = true;
    expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(events, isNot(contains('save')));
    expect(prf.bytes, everyElement(0));
  });

  test('confirmation of a different key never publishes', () async {
    server.wrongKey = true;
    expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(events, isNot(contains('save')));
    expect(events, isNot(contains('trash')));
    expect(prf.bytes, everyElement(0));
  });

  test('revoked consent after store never fetches or publishes', () async {
    metadata.revokeOnRead = 2;
    expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(events, contains('store'));
    expect(events, isNot(contains('fetch')));
    expect(events, isNot(contains('save')));
  });

  test('wrong PRF length is erased and never seals', () async {
    prf.bytes = Uint8List.fromList(List.filled(31, 7));
    expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(prf.bytes, everyElement(0));
    expect(events, isNot(contains('seal')));
  });

  test('cancelled passkey request never seals or stores', () async {
    prf.cancelled = true;
    final result = await create();
    expect(
      (result as Err<VaultCompletion, RecoverBullFailure>).failure,
      isA<VaultCancelledFailure>(),
    );
    expect(events, ['prf']);
  });

  test('late PRF after closure is erased without sealing', () async {
    final wait = Completer<Result<Uint8List, RecoverBullFailure>>();
    prf.wait = wait.future;
    final pending = create();
    usecase.close();
    wait.complete(Ok(prf.bytes));
    expect(await pending, isA<Err<VaultCompletion, RecoverBullFailure>>());
    expect(events, isNot(contains('seal')));
    expect(prf.bytes, everyElement(0));
  });

  test(
    'provider retry writes the same sealed file without server operations',
    () async {
      files.failOnce = true;
      expect(await create(), isA<Err<VaultCompletion, RecoverBullFailure>>());
      expect(usecase.hasPendingProviderSave, isTrue);
      expect(
        await usecase.retryProviderSave(),
        isA<Ok<VaultCompletion, RecoverBullFailure>>(),
      );
      expect(files.saved, hasLength(2));
      expect(files.saved[0], files.saved[1]);
      expect(events.where((event) => event == 'store'), hasLength(1));
      expect(events.where((event) => event == 'fetch'), hasLength(1));
    },
  );

  test('failed markStored is a warning after successful publication', () async {
    metadata.failMark = true;
    final result = await create();
    expect(result, isA<Ok<VaultCompletion, RecoverBullFailure>>());
    final completion =
        (result as Ok<VaultCompletion, RecoverBullFailure>).value;
    expect(completion.warning, isA<VaultStorageFailure>());
    expect(events, contains('save'));
  });
}

final class _Prf implements PasskeySecretPort {
  final List<String> events;
  Uint8List bytes = Uint8List.fromList(List.filled(32, 7));
  Future<Result<Uint8List, RecoverBullFailure>>? wait;
  bool cancelled = false;
  _Prf(this.events);

  @override
  Future<Result<Uint8List, RecoverBullFailure>> get(
    VaultPasskey passkey,
  ) async {
    events.add('prf');
    if (cancelled) return const Err(VaultCancelledFailure());
    final pending = wait;
    if (pending != null) return pending;
    return Ok(bytes);
  }
}

final class _Wallets extends Fake implements RecoverBullWalletPort {
  final VaultContext context;
  _Wallets(this.context);

  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      Ok(context);
}

final class _Vaults extends Fake implements VaultRepository {
  final List<String> events;
  _Vaults(this.events);

  @override
  Future<Result<VaultBackup, RecoverBullFailure>> create(
    VaultContext context,
  ) async {
    events.add('seal');
    return Ok(
      VaultBackup(
        vault: EncryptedVault(
          id: 'ab' * 32,
          salt: 'cd' * 16,
          ciphertext: List.filled(64, 42),
          createdAt: DateTime.fromMillisecondsSinceEpoch(123456),
          derivationPath: "1608'/0'/1'",
        ),
        key: VaultKey('42' * 32),
        context: context,
      ),
    );
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  final List<String> events;
  final BackupSettings current;
  bool failMark = false;
  int revokeOnRead = 0;
  int reads = 0;
  _Metadata(this.events, this.current);

  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async {
    events.add('settings');
    reads++;
    if (revokeOnRead == reads) {
      return Ok(
        BackupSettings(
          server: current.server,
          permissionGranted: false,
          monitoringEnabled: false,
          generation: current.generation,
        ),
      );
    }
    return Ok(current);
  }

  @override
  Future<Result<void, RecoverBullFailure>> markStored(
    VaultContext context,
    EncryptedVault vault,
  ) async {
    events.add('markStored');
    return failMark ? const Err(VaultStorageFailure()) : const Ok(null);
  }
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {
  final List<String> events;
  _Monitoring(this.events);

  @override
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  ) async {
    events.add('register');
    return const Ok(null);
  }

  @override
  Future<Result<OwnBackupOperation, RecoverBullFailure>> begin(
    BackupSettings settings,
    EncryptedVault vault,
  ) async {
    events.add('begin');
    return Ok(OwnBackupOperation(1, settings));
  }

  @override
  Future<Result<void, RecoverBullFailure>> complete(
    OwnBackupOperation operation, {
    AttemptObservation? observation,
    bool lockout = false,
    bool trashed = false,
  }) async {
    events.add('complete');
    return const Ok(null);
  }
}

final class _Server extends Fake implements KeyServerRepository {
  final List<String> events;
  bool failStore = false;
  bool failFetch = false;
  bool wrongKey = false;
  _Server(this.events);

  @override
  Future<Result<void, RecoverBullFailure>> store(
    EncryptedVault vault,
    String password,
    VaultKey key,
  ) async {
    events.add('store');
    return failStore
        ? const Err(KeyServerFailure(KeyServerFailureKind.timeout))
        : const Ok(null);
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> fetch(
    EncryptedVault vault,
    String password,
  ) async {
    events.add('fetch');
    return failFetch
        ? const Err(KeyServerFailure(KeyServerFailureKind.timeout))
        : Ok(VaultKeyFetch(VaultKey((wrongKey ? '43' : '42') * 32), null));
  }

  @override
  Future<Result<VaultKeyFetch, RecoverBullFailure>> trash(
    EncryptedVault vault,
    String password,
  ) async {
    events.add('trash');
    return const Err(VaultInvalidFailure());
  }
}

final class _Files extends Fake implements FileSystem {
  final List<String> events;
  bool failOnce = false;
  final saved = <List<int>>[];
  _Files(this.events);

  @override
  Future<Result<bool, FileSystemFailure>> save({
    required String filename,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    events.add('save');
    saved.add(List.of(bytes));
    if (failOnce) {
      failOnce = false;
      return const Err(FileSystemSaveFailure('synthetic'));
    }
    return const Ok(true);
  }
}

final class _Drive extends Fake implements GoogleDriveRepository {}
