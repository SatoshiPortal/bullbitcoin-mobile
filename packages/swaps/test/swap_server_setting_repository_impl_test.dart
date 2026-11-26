import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swaps/src/data/swap_server_setting_repository_impl.dart';
import 'package:swaps/swaps.dart' show SwapServer, SwapServerCredentials;

import 'support/real_swap_backends.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReproKeychainBackend keychain;
  late SwapServerSettingRepositoryImpl repository;

  const credentials = SwapServerCredentials(
    username: 'bull',
    password: 'p@ss:word',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keychain = ReproKeychainBackend();
    repository = SwapServerSettingRepositoryImpl(secrets: keychain.capability);
  });

  test('nothing stored is the default server without credentials', () async {
    final server = await repository.fetch(isTestnet: false);

    expect(server, SwapServer.mainnetDefault);
    expect(server.credentials, isNull);
  });

  test('credentials are stored as a secret, apart from the address', () async {
    final server = SwapServer.parse(
      'boltz.example.com',
      isTestnet: false,
    )?.withCredentials(credentials);

    await repository.save(
      server ?? SwapServer.mainnetDefault,
      isTestnet: false,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('swaps.boltz.url'), 'boltz.example.com/v2');
    expect(prefs.getKeys().map(prefs.get).join(), isNot(contains('p@ss')));
    expect(keychain.values.values.join(), contains('p@ss:word'));
    expect(await repository.fetch(isTestnet: false), server);
  });

  test('credentials are kept per network', () async {
    await repository.save(
      SwapServer.testnetDefault.withCredentials(credentials),
      isTestnet: true,
    );

    expect((await repository.fetch(isTestnet: true)).credentials, credentials);
    expect((await repository.fetch(isTestnet: false)).credentials, isNull);
  });

  test('the default server keeps its credentials', () async {
    await repository.save(
      SwapServer.mainnetDefault.withCredentials(credentials),
      isTestnet: false,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('swaps.boltz.url'), isNull);
    expect(
      await repository.fetch(isTestnet: false),
      SwapServer.mainnetDefault.withCredentials(credentials),
    );
  });

  test('saving without credentials removes the stored ones', () async {
    await repository.save(
      SwapServer.mainnetDefault.withCredentials(credentials),
      isTestnet: false,
    );

    await repository.save(SwapServer.mainnetDefault, isTestnet: false);

    expect(await repository.fetch(isTestnet: false), SwapServer.mainnetDefault);
    expect(keychain.values.values.join(), isNot(contains('p@ss')));
  });
}
