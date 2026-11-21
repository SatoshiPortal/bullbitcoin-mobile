import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/testing.dart';

void main() {
  late FakeSecureStoragePlatform native;
  late ExchangeKeychainProbe probe;
  setUp(() {
    native = FakeSecureStoragePlatform(
      entries: {
        'exchange_api_key': 'existing-main',
        'exchange_api_key_testnet': 'existing-test',
        'seed_unrelated': 'unrelated',
      },
    )..install();
    probe = ExchangeKeychainProbe()..install();
  });
  tearDown(() => probe.restore());
  test(
    'probe writes and cleanup never reach real credentials even after restore',
    () async {
      await probe.write(
        key: 'exchange_api_key',
        value: 'synthetic-main',
        options: {},
      );
      await probe.write(
        key: 'exchange_api_key_testnet',
        value: 'synthetic-test',
        options: {},
      );
      expect(
        native.entries['__credential_refactor_probe__exchange_api_key'],
        'synthetic-main',
      );
      expect(
        await probe.read(key: 'exchange_api_key_testnet', options: {}),
        'synthetic-test',
      );
      probe.restore();
      await probe.clearWrittenProbeKeys();
      expect(native.entries, {
        'exchange_api_key': 'existing-main',
        'exchange_api_key_testnet': 'existing-test',
        'seed_unrelated': 'unrelated',
      });
    },
  );
  test('only the two fixed exchange entries are permitted', () {
    for (final key in [
      'securityKey',
      'seed_unrelated',
      'swap_id',
      '__credential_refactor_probe__exchange_api_key',
    ]) {
      expect(() => probe.read(key: key, options: {}), throwsArgumentError);
      expect(
        () => probe.write(key: key, value: 'value', options: {}),
        throwsArgumentError,
      );
      expect(() => probe.delete(key: key, options: {}), throwsArgumentError);
      expect(
        () => probe.containsKey(key: key, options: {}),
        throwsArgumentError,
      );
    }
    expect(() => probe.readAll(options: {}), throwsUnsupportedError);
    expect(() => probe.deleteAll(options: {}), throwsUnsupportedError);
    expect(native.reads, 0);
    expect(native.entries, hasLength(3));
  });
  test('synthetic read refusal keeps the native probe value intact', () async {
    await probe.write(key: 'exchange_api_key', value: 'synthetic', options: {});
    probe.refuseReads = true;
    expect(
      () => probe.read(key: 'exchange_api_key', options: {}),
      throwsException,
    );
    probe.refuseReads = false;
    expect(await probe.read(key: 'exchange_api_key', options: {}), 'synthetic');
  });
}
