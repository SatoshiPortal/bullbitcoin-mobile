import 'package:bb_mobile/core/storage/sqlite_database.dart';

class RecoverbullSettingsDatasource {
  final SqliteDatabase _sqlite;

  RecoverbullSettingsDatasource({required SqliteDatabase sqlite})
    : _sqlite = sqlite;

  Future<void> store(Uri url) async {
    await _sqlite
        .into(_sqlite.recoverbull)
        .insertOnConflictUpdate(RecoverbullRow(id: 1, url: url.toString()));
  }

  Future<Uri> fetch() async {
    final row =
        await _sqlite.managers.recoverbull.filter((f) => f.id(1)).getSingle();
    return Uri.parse(row.url);
  }
}
