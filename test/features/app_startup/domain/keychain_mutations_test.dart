import 'dart:io';

import 'package:bb_mobile/features/app_startup/domain/app_startup_failure.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/reset_app_data_usecase.dart';
import 'package:access/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSecureStoragePlatform store;
  late AccessKeychain access;
  setUp(() {
    store = FakeSecureStoragePlatform(entries: {'securityKey': 'previous'})
      ..install();
    access = Secrets(scratchDirectory: () async => Directory.systemTemp.path)
        .accessKeychain;
  });
  test('set, delete and reinstall reset address the same legacy PIN', () async {
    expect(
      await SetPinCodeUsecase(accessKeychain: access).execute('synthetic'),
      isA<Ok>(),
    );
    expect(store.entries['securityKey'], 'synthetic');
    expect(
      await DeletePinCodeUsecase(accessKeychain: access).execute(),
      isA<Ok>(),
    );
    expect(store.entries.containsKey('securityKey'), false);
    store.entries['securityKey'] = 'remaining';
    expect(
      await ResetAppDataUsecase(accessKeychain: access).execute(),
      isA<Ok>(),
    );
    expect(store.entries.containsKey('securityKey'), false);
  });
  test(
    'locked writes preserve both the PIN and each consumer failure category',
    () async {
      store.writesFail = true;
      expect(
        await SetPinCodeUsecase(accessKeychain: access).execute('replacement'),
        isA<Err<Null, AccessFailure>>().having(
          (r) => r.failure,
          'save',
          isA<AccessPinSaveFailure>(),
        ),
      );
      expect(
        await DeletePinCodeUsecase(accessKeychain: access).execute(),
        isA<Err<Null, AccessFailure>>().having(
          (r) => r.failure,
          'delete',
          isA<AccessPinDeleteFailure>(),
        ),
      );
      expect(
        await ResetAppDataUsecase(accessKeychain: access).execute(),
        isA<Err<void, AppStartupFailure>>().having(
          (r) => r.failure,
          'retry',
          isA<AppStartupKeychainLockedFailure>(),
        ),
      );
      expect(store.entries['securityKey'], 'previous');
    },
  );
  test(
    'other reinstall reset failures remain terminal rather than a retry',
    () async {
      store.scriptedWrites.add(Exception('synthetic failure'));
      expect(
        await ResetAppDataUsecase(accessKeychain: access).execute(),
        isA<Err<void, AppStartupFailure>>().having(
          (r) => r.failure,
          'terminal',
          isA<AppStartupResetFailure>(),
        ),
      );
      expect(store.entries['securityKey'], 'previous');
    },
  );
}
