import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/backup_reminder_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_reminder.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/features/backup_settings/ui/backup_options_screen_test.dart'
    as options;
import '../../test/features/backup_settings/ui/backup_reminder_home_test.dart'
    as reminders;
import '../../test/features/backup_settings/ui/backup_settings_screen_test.dart'
    as recovery;

import '../../test/features/backup_settings/domain/backup_reminder_test.dart'
    as timing;

// Run separately from the app's storage integration suite: these UI fixtures
// supply wallet facts and own their locator registrations. The first test uses
// real platform preferences; the shared widget cases use in-memory preferences.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reminder disable and re-enable persist through the platform', (
    tester,
  ) async {
    final repository = BackupReminderRepositoryImpl();
    expect(
      await repository.setDisabled(true),
      isA<Ok<void, BackupSettingsFailure>>(),
    );
    var result = await BackupReminderRepositoryImpl().load();
    expect(
      (result as Ok<BackupReminderPreferences, BackupSettingsFailure>)
          .value
          .disabled,
      isTrue,
    );
    expect(
      await repository.setDisabled(false),
      isA<Ok<void, BackupSettingsFailure>>(),
    );
    result = await BackupReminderRepositoryImpl().load();
    expect(
      (result as Ok<BackupReminderPreferences, BackupSettingsFailure>)
          .value
          .disabled,
      isFalse,
    );
  });

  group('Reminder timing and priority', timing.main);
  group('Wallet Recovery presentation', recovery.main);
  group('Reminder dialogs and controls', reminders.main);
  group('Backup options', options.main);
}
