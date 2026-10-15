import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/pending_vault_backup.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_lifecycle_port.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_attempt_monitoring_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_vault_to_provider_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';

class _SaveFile extends Mock implements SaveFileToSystemUsecase {}

class _Connect extends Mock implements ConnectToGoogleDriveUsecase {}

class _SaveDrive extends Mock implements SaveVaultToGoogleDriveUsecase {}

class _Monitoring extends Mock
    implements RecoverBullAttemptMonitoringRepository {}

class _Lifecycle extends Mock implements RecoverBullLifecyclePort {}

void main() {
  late _SaveFile file;
  late _Connect connect;
  late _SaveDrive drive;
  late _Monitoring monitoring;
  late _Lifecycle lifecycle;
  late TestLogSink log;
  late SaveVaultToProviderUsecase usecase;
  final pending = PendingVaultBackup(
    vault: EncryptedVault(
      id: List.filled(32, '01').join(),
      salt: List.filled(16, '02').join(),
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    ),
    network: RecoverBullNetwork.testnet,
  );
  setUpAll(() => registerFallbackValue(pending.vault));
  setUp(() {
    file = _SaveFile();
    connect = _Connect();
    drive = _SaveDrive();
    monitoring = _Monitoring();
    lifecycle = _Lifecycle();
    log = TestLogSink.recording();
    when(
      () => monitoring.registerBackup(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => lifecycle.markStored(pending.network)).thenAnswer((_) async {});
    usecase = SaveVaultToProviderUsecase(
      log: log,
      saveFile: file,
      connectDrive: connect,
      saveDrive: drive,
      registerBackup: RegisterMonitoredBackupUsecase(monitoring),
      lifecycle: lifecycle,
    );
  });

  test(
    'a saved file remains successful when both advisory writes throw',
    () async {
      when(
        () => file.execute(vault: pending.vault),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => monitoring.registerBackup(any()),
      ).thenThrow(Exception('private registration detail'));
      when(
        () => lifecycle.markStored(pending.network),
      ).thenThrow(Exception('private lifecycle detail'));
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.customLocation,
        cancelled: () => false,
      );
      expect(
        (result as Ok<PendingVaultBackup, RecoverBullFailure>).value,
        same(pending),
      );
      verify(() => lifecycle.markStored(pending.network)).called(1);
      verifyNever(connect.execute);
      expect(
        log.entries.map((entry) => entry.message).join(),
        isNot(contains('private')),
      );
    },
  );

  test(
    'a saved file remains successful when monitoring returns a typed failure',
    () async {
      when(
        () => file.execute(vault: pending.vault),
      ).thenAnswer((_) async => const Ok(null));
      when(() => monitoring.registerBackup(any())).thenAnswer(
        (_) async =>
            const Err(RecoverBullUnexpectedFailure('private storage detail')),
      );
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.customLocation,
        cancelled: () => false,
      );
      expect(result, isA<Ok<PendingVaultBackup, RecoverBullFailure>>());
      verify(() => lifecycle.markStored(pending.network)).called(1);
    },
  );

  test(
    'Drive canceled authentication prevents upload and advisory writes',
    () async {
      when(
        connect.execute,
      ).thenAnswer((_) async => const Err(SelectVaultFailure()));
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.googleDrive,
        cancelled: () => false,
      );
      expect(
        (result as Err<PendingVaultBackup, RecoverBullFailure>).failure,
        isA<VaultProviderSaveFailure>(),
      );
      verifyNever(() => drive.execute(any()));
      verifyNever(() => monitoring.registerBackup(any()));
      verifyNever(() => lifecycle.markStored(pending.network));
    },
  );

  test('abandoning the flow while Drive connects prevents upload', () async {
    final connection = Completer<Result<Null, RecoverBullFailure>>();
    when(connect.execute).thenAnswer((_) => connection.future);
    var cancelled = false;
    final save = usecase.execute(
      pending: pending,
      provider: VaultProvider.googleDrive,
      cancelled: () => cancelled,
    );
    cancelled = true;
    connection.complete(const Ok(null));
    expect(await save, isA<Err<PendingVaultBackup, RecoverBullFailure>>());
    verifyNever(() => drive.execute(any()));
  });

  test(
    'successful Drive save uploads the vault before marking its network stored',
    () async {
      final order = <String>[];
      when(connect.execute).thenAnswer((_) async {
        order.add('connect');
        return const Ok(null);
      });
      when(() => drive.execute(pending.vault)).thenAnswer((_) async {
        order.add('upload');
        return const Ok(null);
      });
      when(() => lifecycle.markStored(pending.network)).thenAnswer((_) async {
        order.add('mark');
      });
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.googleDrive,
        cancelled: () => false,
      );
      expect(
        (result as Ok<PendingVaultBackup, RecoverBullFailure>).value,
        same(pending),
      );
      expect(order, ['connect', 'upload', 'mark']);
      verifyNever(() => file.execute(vault: any(named: 'vault')));
    },
  );
  test('failed external saves never mark the backup stored', () async {
    when(() => file.execute(vault: pending.vault)).thenAnswer(
      (_) async =>
          const Err(RecoverBullUnexpectedFailure('private disk detail')),
    );
    final result = await usecase.execute(
      pending: pending,
      provider: VaultProvider.customLocation,
      cancelled: () => false,
    );
    expect(
      (result as Err<PendingVaultBackup, RecoverBullFailure>).failure,
      isA<VaultProviderSaveFailure>(),
    );
    verifyNever(() => monitoring.registerBackup(any()));
    verifyNever(() => lifecycle.markStored(pending.network));
  });

  test(
    'thrown infrastructure exceptions map safely without sensitive log detail',
    () async {
      when(
        () => file.execute(vault: pending.vault),
      ).thenThrow(Exception('private file detail'));
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.customLocation,
        cancelled: () => false,
      );
      expect(
        (result as Err<PendingVaultBackup, RecoverBullFailure>).failure,
        isA<VaultProviderSaveFailure>(),
      );
      expect(
        log.entries.map((entry) => entry.message).join(),
        isNot(contains('private file detail')),
      );
      verifyNever(() => lifecycle.markStored(pending.network));
    },
  );

  test(
    'unsupported providers perform no external save or advisory write',
    () async {
      final result = await usecase.execute(
        pending: pending,
        provider: VaultProvider.iCloud,
        cancelled: () => false,
      );
      expect(
        (result as Err<PendingVaultBackup, RecoverBullFailure>).failure,
        isA<SelectVaultFailure>(),
      );
      verifyNever(() => file.execute(vault: any(named: 'vault')));
      verifyNever(connect.execute);
      verifyNever(() => drive.execute(any()));
      verifyNever(() => monitoring.registerBackup(any()));
      verifyNever(() => lifecycle.markStored(pending.network));
    },
  );
}
