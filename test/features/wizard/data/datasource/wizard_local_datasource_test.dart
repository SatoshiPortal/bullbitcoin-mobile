import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late _MockSharedPreferences preferences;
  late WizardLocalDatasourceImpl datasource;

  setUp(() {
    preferences = _MockSharedPreferences();
    datasource = WizardLocalDatasourceImpl(
      loadPreferences: () async => preferences,
    );
  });

  test('fails when the backup choice is not durable', () async {
    when(
      () => preferences.setBool('wizard_pending_metadata_backup', true),
    ).thenAnswer((_) async => false);

    await expectLater(
      datasource.writePendingMetadataBackup(true),
      throwsA(isA<WizardPersistenceException>()),
    );
  });

  test('fails when the completion marker is not durable', () async {
    when(
      () => preferences.setInt('wizard_completed_version', 2),
    ).thenAnswer((_) async => false);

    await expectLater(
      datasource.writeCompletedVersion(2),
      throwsA(isA<WizardPersistenceException>()),
    );
  });
}
