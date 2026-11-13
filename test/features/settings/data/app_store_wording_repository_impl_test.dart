import 'package:bb_mobile/features/settings/data/app_store_wording_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('is not forced by default', () async {
    final result = await AppStoreWordingRepositoryImpl().isForced();
    expect(result, isA<Ok<bool, dynamic>>());
    expect((result as Ok<bool, dynamic>).value, isFalse);
  });

  test('persists the switch across repository instances', () async {
    expect(await AppStoreWordingRepositoryImpl().setForced(true), isA<Ok>());
    final reread = await AppStoreWordingRepositoryImpl().isForced();
    expect((reread as Ok<bool, dynamic>).value, isTrue);

    expect(await AppStoreWordingRepositoryImpl().setForced(false), isA<Ok>());
    final cleared = await AppStoreWordingRepositoryImpl().isForced();
    expect((cleared as Ok<bool, dynamic>).value, isFalse);
  });
}
