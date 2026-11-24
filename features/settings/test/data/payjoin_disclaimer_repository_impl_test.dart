import 'package:primitives/primitives.dart';
import 'package:settings/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PayjoinDisclaimerRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = PayjoinDisclaimerRepositoryImpl();
  });

  test('defaults to not shown when the preference is absent', () async {
    final result = await repository.hasBeenShown();

    expect(result, isA<Ok<bool, SettingsFailure>>());
    expect((result as Ok<bool, SettingsFailure>).value, isFalse);
  });

  test('persists that the disclaimer has been shown', () async {
    final markResult = await repository.markShown();
    final readResult = await repository.hasBeenShown();

    expect(markResult, isA<Ok<void, SettingsFailure>>());
    expect((readResult as Ok<bool, SettingsFailure>).value, isTrue);
  });
}
