import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/select_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Pick extends Mock implements PickVaultUsecase {}

class _Connect extends Mock implements ConnectToGoogleDriveUsecase {}

class _Latest extends Mock implements FetchLatestGoogleDriveVaultUsecase {}

void main() {
  late _Pick pick;
  late _Connect connect;
  late _Latest latest;
  late SelectVaultUsecase usecase;
  final vault = EncryptedVault(
    id: List.filled(32, '01').join(),
    salt: List.filled(16, '02').join(),
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );
  setUp(() {
    pick = _Pick();
    connect = _Connect();
    latest = _Latest();
    usecase = SelectVaultUsecase(
      pick: pick,
      connectDrive: connect,
      latestDrive: latest,
    );
  });

  test(
    'canceling while Drive connects prevents reading the latest backup',
    () async {
      final connection = Completer<Result<Null, RecoverBullFailure>>();
      when(connect.execute).thenAnswer((_) => connection.future);
      var cancelled = false;
      final selection = usecase.execute(
        provider: VaultProvider.googleDrive,
        cancelled: () => cancelled,
      );
      cancelled = true;
      connection.complete(const Ok(null));
      final result = await selection;
      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        isA<SelectVaultFailure>(),
      );
      verifyNever(latest.execute);
      verifyNever(pick.execute);
    },
  );

  test('Drive authentication failure stops before fetching a vault', () async {
    when(connect.execute).thenAnswer(
      (_) async => const Err(
        RecoverBullUnexpectedFailure('private authentication detail'),
      ),
    );
    final result = await usecase.execute(
      provider: VaultProvider.googleDrive,
      cancelled: () => false,
    );
    expect(
      (result as Err<EncryptedVault, RecoverBullFailure>).failure,
      isA<SelectVaultFailure>(),
    );
    verifyNever(latest.execute);
  });

  test(
    'Drive infrastructure failure maps to a safe selection failure',
    () async {
      when(connect.execute).thenAnswer((_) async => const Ok(null));
      when(latest.execute).thenAnswer(
        (_) async =>
            const Err(RecoverBullUnexpectedFailure('private transport detail')),
      );
      final result = await usecase.execute(
        provider: VaultProvider.googleDrive,
        cancelled: () => false,
      );
      final failure =
          (result as Err<EncryptedVault, RecoverBullFailure>).failure;
      expect(failure, isA<SelectVaultFailure>());
      expect(failure.logMessage, isNot('private transport detail'));
    },
  );

  test(
    'an invalid local file keeps its specific recoverable failure',
    () async {
      when(
        pick.execute,
      ).thenAnswer((_) async => const Err(InvalidVaultFileFailure()));
      final result = await usecase.execute(
        provider: VaultProvider.customLocation,
        cancelled: () => false,
      );
      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        isA<InvalidVaultFileFormatFailure>(),
      );
      verifyNever(connect.execute);
    },
  );

  test(
    'local and Drive providers return the selected validated vault',
    () async {
      when(pick.execute).thenAnswer((_) async => Ok(vault));
      when(connect.execute).thenAnswer((_) async => const Ok(null));
      when(latest.execute).thenAnswer((_) async => Ok(vault));
      for (final provider in [
        VaultProvider.customLocation,
        VaultProvider.googleDrive,
      ]) {
        final result = await usecase.execute(
          provider: provider,
          cancelled: () => false,
        );
        expect(
          (result as Ok<EncryptedVault, RecoverBullFailure>).value,
          same(vault),
        );
      }
    },
  );

  test(
    'unsupported providers do not start a picker or Drive session',
    () async {
      final result = await usecase.execute(
        provider: VaultProvider.iCloud,
        cancelled: () => false,
      );
      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        isA<SelectVaultFailure>(),
      );
      verifyNever(pick.execute);
      verifyNever(connect.execute);
      verifyNever(latest.execute);
    },
  );
}
