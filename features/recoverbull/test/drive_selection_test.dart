import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_drive/google_drive.dart';

void main() {
  test('a Drive delete confirmation cannot cross an account change', () async {
    final drive = _Drive();
    final repository = GoogleDriveRepositoryImpl(drive: drive);
    addTearDown(repository.dispose);

    expect(await repository.connect(), isA<Ok<Null, RecoverBullFailure>>());
    final files = await repository.fetchAllMetadata();
    final selected = files.fold(
      (files) => files.single,
      (_) => fail('could not list the account files'),
    );
    drive.account = 'second@example.invalid';
    final deleted = await repository.trash(selected);
    expect(deleted, isA<Err<Null, RecoverBullFailure>>());
    expect(drive.deletes, 0);
  });
}

final class _Drive extends Fake implements GoogleDrive {
  String account = 'first@example.invalid';
  int deletes = 0;

  @override
  Future<Result<void, GoogleDriveFailure>> connect() async => const Ok(null);

  @override
  Future<Result<String?, GoogleDriveFailure>> connectSilently() async =>
      Ok(account);

  @override
  Future<Result<List<GoogleDriveFileMetadata>, GoogleDriveFailure>> listFiles({
    String? mimeType,
  }) async => Ok([
    GoogleDriveFileMetadata(
      id: 'file',
      name: 'vault.json',
      createdTime: DateTime.utc(2026, 11, 9),
    ),
  ]);

  @override
  Future<Result<void, GoogleDriveFailure>> deleteFile(String fileId) async {
    deletes++;
    return const Ok(null);
  }

  @override
  void dispose() {}
}
