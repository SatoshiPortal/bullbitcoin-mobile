import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:wizard/src/data/datasource/wizard_local_datasource.dart';
import 'package:wizard/src/data/repository/wizard_repository_impl.dart';
import 'package:preferences/preferences.dart' show Environment;

class FailingPreferences extends InMemorySharedPreferencesStore {
  FailingPreferences() : super.empty();

  bool failRemove = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;

  @override
  Future<bool> remove(String key) async => !failRemove;
}

class PartiallyFailingPreferences extends InMemorySharedPreferencesStore {
  PartiallyFailingPreferences()
    : super.withData({
        'flutter.wizard_pending_version': kCurrentWizardVersion,
        'flutter.wizard_pending_language': 'unitedStatesEnglish',
        'flutter.wizard_pending_network': 'testnet',
        'flutter.wizard_pending_screen_privacy': false,
      });

  bool failLanguageRemoval = true;

  @override
  Future<bool> remove(String key) async {
    if (failLanguageRemoval && key == 'flutter.wizard_pending_language') {
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform previous;
  late FailingPreferences store;

  setUp(() {
    previous = SharedPreferencesStorePlatform.instance;
    store = FailingPreferences();
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
  });

  tearDown(() {
    SharedPreferencesStorePlatform.instance = previous;
    SharedPreferences.resetStatic();
  });

  test('false writes and removals are reported as failures', () async {
    final datasource = WizardLocalDatasourceImpl();
    for (final write in <Future<void> Function()>[
      () => datasource.writeCompletedVersion(1),
      () => datasource.writePendingVersion(1),
      () => datasource.writePendingLanguage('en'),
      () => datasource.writePendingThemeMode('light'),
      () => datasource.writePendingCurrency('USD'),
      () => datasource.writePendingErrorReporting(false),
      () => datasource.writePendingExchangeAccess(true),
      () => datasource.writePendingBackgroundTasks(true),
      () => datasource.writePendingNetwork('testnet'),
      () => datasource.writePendingScreenPrivacy(false),
    ]) {
      await expectLater(write(), throwsException);
    }
    store.failRemove = true;
    await expectLater(datasource.clearAllPending(), throwsException);
    await expectLater(datasource.clearPendingNetwork(), throwsException);
  });

  test('failed cleanup retains a readable version until retry', () async {
    final partial = PartiallyFailingPreferences();
    SharedPreferencesStorePlatform.instance = partial;
    SharedPreferences.resetStatic();
    final repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());
    await expectLater(repository.clearPending(), throwsException);
    SharedPreferences.resetStatic();
    final remaining = await repository.readPending();
    expect(remaining?.network, Environment.testnet);
    expect(remaining?.screenPrivacy, isFalse);
    partial.failLanguageRemoval = false;
    await repository.clearPending();
    SharedPreferences.resetStatic();
    expect(await repository.readPending(), isNull);
  });
}
