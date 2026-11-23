import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:backup_storage/backup_storage.dart';
import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';

void main() {
  test('a Drive delete confirmation cannot cross an account change', () async {
    final drive = _Drive();
    final repository = GoogleDriveRepositoryImpl(
      datasource: GoogleDriveAppDatasource(storage: drive),
    );
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

final class _Drive extends Fake implements BackupStorage {
  String account = 'first@example.invalid';
  int deletes = 0;

  @override
  Future<Result<StorageSession, BackupStorageFailure>> authorize({
    required bool interactive,
  }) async => Ok(_Session(this, StorageAccount(id: account)));
}

final class _Session extends Fake implements StorageSession {
  final _Drive owner;
  @override
  final StorageAccount account;
  _Session(this.owner, this.account);

  @override
  Future<Result<List<StoredObject>, BackupStorageFailure>> list({
    required String mimeType,
    String? namePrefix,
  }) async => Ok([
    StoredObject(
      id: 'file',
      name: 'vault.json',
      createdAt: DateTime.utc(2026, 11, 9),
      durability: Durability.durable,
    ),
  ]);

  @override
  Future<Result<void, BackupStorageFailure>> delete(StoredObject object) async {
    owner.deletes++;
    return const Ok(null);
  }

  @override
  void dispose() {}
}
