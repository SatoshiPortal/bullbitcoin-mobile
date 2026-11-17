import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/repositories/attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/backup_metadata_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/key_server_session_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_file_repository.dart';
import 'package:bull_recoverbull/src/domain/repositories/vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/complete_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_and_store_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/manage_vault_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/open_key_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Sessions sessions;
  late ManageVaultSessionUsecase session;

  setUp(() {
    sessions = _Sessions();
    final metadata = _Metadata();
    final monitoring = _Monitoring();
    final fetch = FetchVaultKeyUsecase(monitoring);
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(_Vaults(), _Wallets()),
      RestoreVaultUsecase(_Vaults(), _Wallets()),
      null,
      null,
    );
    session = ManageVaultSessionUsecase(
      metadata,
      OpenKeyServerUsecase(metadata, sessions),
      fetch,
      CreateAndStoreVaultUsecase(
        CreateVaultUsecase(_Vaults(), _Wallets()),
        SaveVaultUsecase(_Files(), _Drive()),
        metadata,
        monitoring,
        fetch,
      ),
      complete,
    );
  });

  test('a dead local Tor session is replaced on the next action', () async {
    sessions.next = [
      _Server(
        const Err(
          KeyServerFailure(
            KeyServerFailureKind.unavailable,
            cause: KeyServerUnreachableCause.proxyGone,
          ),
        ),
      ),
      _Server(const Ok(null)),
    ];

    expect(await session.connect(), isA<Err<void, RecoverBullFailure>>());
    expect(sessions.opened.single.closed, isTrue);

    expect(await session.connect(), isA<Ok<void, RecoverBullFailure>>());
    expect(sessions.opened, hasLength(2));
    await session.close();
  });

  test('a server outage keeps the session for Retry', () async {
    sessions.next = [
      _Server(
        const Err(
          KeyServerFailure(
            KeyServerFailureKind.timeout,
            cause: KeyServerUnreachableCause.circuitTimeout,
          ),
        ),
      ),
    ];

    await session.connect();
    expect(sessions.opened.single.closed, isFalse);
    await session.close();
  });
}

final class _Server extends Fake implements KeyServerRepository {
  final Result<void, RecoverBullFailure> answer;
  bool closed = false;

  _Server(this.answer);

  @override
  Future<Result<void, RecoverBullFailure>> probe() async => answer;

  @override
  Future<void> close() async => closed = true;
}

final class _Sessions implements KeyServerSessionRepository {
  List<_Server> next = [];
  final List<_Server> opened = [];

  @override
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async {
    final session = next.removeAt(0);
    opened.add(session);
    return Ok(session);
  }
}

final class _Metadata extends Fake implements BackupMetadataRepository {
  @override
  Future<Result<BackupSettings, RecoverBullFailure>> settings() async => Ok(
    BackupSettings(
      server: Uri.parse(
        'http://5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion',
      ),
      permissionGranted: true,
      monitoringEnabled: false,
      generation: 1,
    ),
  );
}

final class _Monitoring extends Fake implements AttemptMonitoringRepository {}

final class _Files extends Fake implements VaultFileRepository {}

final class _Drive extends Fake implements GoogleDriveRepository {}

final class _Vaults extends Fake implements VaultRepository {}

final class _Wallets extends Fake implements RecoverBullWalletPort {}
