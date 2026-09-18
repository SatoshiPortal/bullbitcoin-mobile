import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUp(SharedPreferences.resetStatic);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  for (final throws in [false, true]) {
    test(
      'a ${throws ? 'throwing' : 'rejected'} write cannot disable reminders in memory',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getAll') return <String, Object>{};
              if (throws) throw PlatformException(code: 'storage_unavailable');
              return false;
            });
        final repository = BackupReminderRepositoryImpl();
        expect(
          await repository.setDisabled(true),
          isA<Err<void, BackupSettingsFailure>>(),
        );
        final loaded = await repository.load();
        expect(
          (loaded as Ok<BackupReminderPreferences, BackupSettingsFailure>)
              .value
              .disabled,
          isFalse,
        );
      },
    );
  }
}
