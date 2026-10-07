import 'package:bull_recoverbull/src/data/file_system_repository.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/repositories/google_drive_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/delete_drive_file_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/export_drive_file_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_file_to_system_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Drive extends Mock implements GoogleDriveRepository {}

class _Files extends Mock implements FileSystemRepository {}

void main() {
  const vaultFile =
      '{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608\'/0\'/586053381"}';
  late _Drive drive;
  late _Files files;
  const failure = KeyServerConnectionFailure();
  final meta = DriveFileMetadata(
    id: 'file-id',
    name: 'vault.json',
    createdTime: DateTime.utc(2026),
  );

  setUp(() {
    drive = _Drive();
    files = _Files();
  });

  group('PickVaultUsecase', () {
    test('returns the picked vault', () async {
      final vault = EncryptedVault(file: vaultFile);
      when(() => files.pickVault()).thenAnswer((_) async => Ok(vault));

      final result = await PickVaultUsecase(
        fileSystemRepository: files,
      ).execute();

      expect((result as Ok<EncryptedVault, RecoverBullFailure>).value, vault);
    });

    test('propagates the repository failure', () async {
      when(
        () => files.pickVault(),
      ).thenAnswer((_) async => const Err(InvalidVaultFileFailure()));

      final result = await PickVaultUsecase(
        fileSystemRepository: files,
      ).execute();

      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        isA<InvalidVaultFileFailure>(),
      );
    });
  });

  group('SaveFileToSystemUsecase', () {
    test('delegates content and filename and returns Ok', () async {
      when(
        () => files.saveFile('content', 'name.json'),
      ).thenAnswer((_) async => const Ok(null));

      final result = await SaveFileToSystemUsecase(
        fileSystemRepository: files,
      ).execute(content: 'content', filename: 'name.json');

      expect(result, isA<Ok<Null, RecoverBullFailure>>());
      verify(() => files.saveFile('content', 'name.json')).called(1);
    });

    test('propagates the repository failure', () async {
      when(
        () => files.saveFile(any(), any()),
      ).thenAnswer((_) async => const Err(failure));

      final result = await SaveFileToSystemUsecase(
        fileSystemRepository: files,
      ).execute(content: 'c', filename: 'f');

      expect((result as Err<Null, RecoverBullFailure>).failure, failure);
    });
  });

  group('DeleteDriveFileUsecase', () {
    test('trashes the file by id', () async {
      when(
        () => drive.trash('file-id'),
      ).thenAnswer((_) async => const Ok(null));

      final result = await DeleteDriveFileUsecase(
        driveRepository: drive,
      ).execute('file-id');

      expect(result, isA<Ok<Null, RecoverBullFailure>>());
      verify(() => drive.trash('file-id')).called(1);
    });

    test('propagates the repository failure', () async {
      when(
        () => drive.trash(any()),
      ).thenAnswer((_) async => const Err(failure));

      final result = await DeleteDriveFileUsecase(
        driveRepository: drive,
      ).execute('x');

      expect((result as Err<Null, RecoverBullFailure>).failure, failure);
    });
  });

  group('ExportDriveFileUsecase', () {
    ExportDriveFileUsecase build() => ExportDriveFileUsecase(
      driveRepository: drive,
      fileSystemRepository: files,
    );

    test('saves the raw Drive content under the Drive file name', () async {
      when(
        () => drive.fetchRawFile('file-id'),
      ).thenAnswer((_) async => const Ok('raw'));
      when(
        () => files.saveFile('raw', 'vault.json'),
      ).thenAnswer((_) async => const Ok(null));

      final result = await build().execute(meta);

      expect(result, isA<Ok<Null, RecoverBullFailure>>());
      verify(() => files.saveFile('raw', 'vault.json')).called(1);
    });

    test('does not save when the Drive fetch fails', () async {
      when(
        () => drive.fetchRawFile(any()),
      ).thenAnswer((_) async => const Err(failure));

      final result = await build().execute(meta);

      expect((result as Err<Null, RecoverBullFailure>).failure, failure);
      verifyNever(() => files.saveFile(any(), any()));
    });

    test('propagates a save failure', () async {
      when(
        () => drive.fetchRawFile(any()),
      ).thenAnswer((_) async => const Ok('raw'));
      when(
        () => files.saveFile(any(), any()),
      ).thenAnswer((_) async => const Err(SelectVaultFailure()));

      final result = await build().execute(meta);

      expect(
        (result as Err<Null, RecoverBullFailure>).failure,
        isA<SelectVaultFailure>(),
      );
    });
  });

  group('FetchAllDriveFileMetadataUsecase', () {
    test('connects then returns the metadata', () async {
      when(() => drive.connect()).thenAnswer((_) async => const Ok(null));
      when(() => drive.fetchAllMetadata()).thenAnswer((_) async => Ok([meta]));

      final result = await FetchAllDriveFileMetadataUsecase(
        driveRepository: drive,
      ).execute();

      expect(
        (result as Ok<List<DriveFileMetadata>, RecoverBullFailure>).value,
        [meta],
      );
      verifyInOrder([() => drive.connect(), () => drive.fetchAllMetadata()]);
    });

    test('returns the connect failure without listing files', () async {
      when(() => drive.connect()).thenAnswer((_) async => const Err(failure));

      final result = await FetchAllDriveFileMetadataUsecase(
        driveRepository: drive,
      ).execute();

      expect(
        (result as Err<List<DriveFileMetadata>, RecoverBullFailure>).failure,
        failure,
      );
      verifyNever(() => drive.fetchAllMetadata());
    });

    test('propagates a listing failure', () async {
      when(() => drive.connect()).thenAnswer((_) async => const Ok(null));
      when(
        () => drive.fetchAllMetadata(),
      ).thenAnswer((_) async => const Err(failure));

      final result = await FetchAllDriveFileMetadataUsecase(
        driveRepository: drive,
      ).execute();

      expect(result, isA<Err<List<DriveFileMetadata>, RecoverBullFailure>>());
    });
  });

  group('FetchVaultFromDriveUsecase', () {
    test('fetches the vault by the metadata id', () async {
      final vault = EncryptedVault(file: vaultFile);
      when(
        () => drive.fetchVault('file-id'),
      ).thenAnswer((_) async => Ok(vault));

      final result = await FetchVaultFromDriveUsecase(
        driveRepository: drive,
      ).execute(meta);

      expect((result as Ok<EncryptedVault, RecoverBullFailure>).value, vault);
    });

    test('propagates the repository failure', () async {
      when(
        () => drive.fetchVault(any()),
      ).thenAnswer((_) async => const Err(failure));

      final result = await FetchVaultFromDriveUsecase(
        driveRepository: drive,
      ).execute(meta);

      expect(
        (result as Err<EncryptedVault, RecoverBullFailure>).failure,
        failure,
      );
    });
  });
}
