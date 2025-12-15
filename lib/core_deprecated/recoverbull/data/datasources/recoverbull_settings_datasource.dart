import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:drift/drift.dart';

class RecoverbullSettingsDatasource {
  final SqliteDatabase _sqlite;

  RecoverbullSettingsDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(Uri url) async {
    await _sqlite
        .into(_sqlite.recoverbull)
        .insertOnConflictUpdate(
          RecoverbullRow(
            id: 1,
            url: url.toString(),
            isPermissionGranted: false,
          ),
        );
  }

  Future<Uri> fetch() async {
    final row = await _sqlite.managers.recoverbull
        .filter((f) => f.id(1))
        .getSingle();
    return Uri.parse(row.url);
  }

  Future<void> allowPermission(bool isGranted) async {
    await _sqlite.managers.recoverbull.update(
      (f) => f(id: const Value(1), isPermissionGranted: Value(isGranted)),
    );
  }

  Future<bool> fetchPermission() async {
    final row = await _sqlite.managers.recoverbull
        .filter((f) => f.id(1))
        .getSingle();
    return row.isPermissionGranted;
  }
}
