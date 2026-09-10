import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/recoverbull_setup.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';

void main() {
  SqliteDatabase database() => SqliteDatabase(NativeDatabase.memory());

  test(
    'migration matrix distinguishes absent, empty, and invalid URLs',
    () async {
      final absent = database();
      await absent.customStatement('DELETE FROM recoverbull');
      expect(
        (await readRecoverBullLegacySettings(absent)).wasImported,
        isFalse,
      );
      await absent.close();

      final empty = database();
      await empty
          .into(empty.recoverbull)
          .insert(
            RecoverbullCompanion.insert(url: '', isPermissionGranted: false),
          );
      expect((await readRecoverBullLegacySettings(empty)).serverUrl, isNull);
      await empty.close();

      final invalid = database();
      await invalid
          .into(invalid.recoverbull)
          .insert(
            RecoverbullCompanion.insert(
              url: 'not a recoverbull server',
              isPermissionGranted: false,
            ),
          );
      expect((await readRecoverBullLegacySettings(invalid)).serverUrl, isNull);
      await invalid.close();
    },
  );

  test('migration reports an unreadable legacy database for retry', () async {
    final legacy = database();
    var reported = false;
    await legacy.customStatement('DROP TABLE recoverbull');

    final settings = await readRecoverBullLegacySettings(
      legacy,
      onReadFailure: () => reported = true,
    );

    expect(settings.readFailed, isTrue);
    expect(reported, isTrue);
  });

  test(
    'migration can be replayed without overwriting package settings',
    () async {
      final package = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await package.ensureState(
        initialServerUrlOverride: 'http://existing.onion',
      );
      await package.ensureState(
        initialServerUrlOverride: 'http://legacy.onion',
      );

      final state = await package.select(package.recoverbullState).getSingle();
      expect(state.serverUrlOverride, 'http://existing.onion');
      await package.close();
    },
  );
}
