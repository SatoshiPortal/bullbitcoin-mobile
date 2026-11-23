import 'package:drift/native.dart';
import 'package:electrum/setup.dart';
import 'package:fees/fees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/sync.dart';

class _Preferences extends Mock implements settings.Preferences {}

class _Electrum extends Mock implements ElectrumServersPort {}

class _Chain extends Mock implements WalletConnectionPort {}

class _Fees extends Mock implements Fees {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('open owns one engine and the historical autoswap rows', () async {
    SharedPreferences.setMockInitialValues({});
    FakeSecureStoragePlatform().install();
    final prefs = _Preferences();
    var environment = settings.Environment.mainnet;
    when(prefs.fetch).thenAnswer(
      (_) async => Ok(
        settings.SettingsEntity(
          environment: environment,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      ),
    );
    final database = BoltzSwapsDatabase(NativeDatabase.memory());
    final regtest = BoltzSwapsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    addTearDown(regtest.close);
    final opened = await Swaps.open(
      database: database,
      regtestDatabase: regtest,
      preferences: prefs,
      secrets: Secrets(scratchDirectory: () async => '/unused'),
      electrum: _Electrum(),
      connections: _Chain(),
      fees: _Fees(),
      wallets: (_) async => throw StateError('open must not read wallets'),
      defaultBitcoinFingerprint: (_) async =>
          throw StateError('open must not derive a key'),
      newAddressFor: (_) async => throw StateError('no address expected'),
      walletTx: (_, {required walletId}) async => null,
      walletTxs: (_, {bool sync = false}) async => const [],
    );
    expect(opened, isA<Ok<Swaps, SwapsFailure>>());
    final swaps = (opened as Ok<Swaps, SwapsFailure>).value;
    addTearDown(swaps.close);
    expect(swaps.store, same(swaps.resolver));
    expect(swaps.store, same(swaps.boltz));
    expect(swaps.watcher.isRunning, isFalse);

    const mainnet = AutoSwap(enabled: false, balanceThresholdSats: 110000);
    const testnet = AutoSwap(enabled: false, balanceThresholdSats: 210000);
    expect(await swaps.saveAutoSwap(mainnet), isA<Ok>());
    environment = settings.Environment.testnet;
    expect(await swaps.saveAutoSwap(testnet), isA<Ok>());
    expect((await swaps.readAutoSwap() as Ok).value, testnet);

    environment = settings.Environment.regtest;
    expect(
      await swaps.saveAutoSwap(const AutoSwap(enabled: false)),
      isA<Err>().having(
        (result) => result.failure,
        'failure',
        isA<SwapsUnsupportedNetworkFailure>(),
      ),
    );
    environment = settings.Environment.mainnet;
    expect((await swaps.readAutoSwap() as Ok).value, mainnet);
    final closing = swaps.close();
    expect(swaps.close(), same(closing));
    await closing;
    final _ = await database.select(database.autoSwap).get();
  });
}
