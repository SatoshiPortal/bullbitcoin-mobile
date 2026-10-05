import 'dart:io';

import 'package:bb_mobile/main.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Pins the BIP352 scan credential `secrets` derives in Dart against bwk, on
/// the FFI the unit suite cannot load.
///
/// The app opens its silent payments account from the credential alone, so a
/// derivation that drifted from BIP352 would not fail: it would watch a
/// different wallet, and a restore in any other BIP352 wallet would not find
/// the funds. bwk opens a watch-only account from the package's descriptors on
/// every network, and on mainnet and regtest the addresses it reports must be
/// the ones it reports for the descriptors bwk-dart's own fixtures derive from
/// the same words (`derive` in rust/tests/common/mod.rs, rust-bitcoin
/// directly). Offline: no account here syncs.
Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  // The published BIP39 vector for zero entropy. Public, so no funds and
  // nothing to leak.
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Directory scratch;
  late Secret secret;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('sp_vectors_');
    final secrets = Secrets(scratchDirectory: () async => scratch.path);
    secret = switch (await secrets.import(words: words)) {
      Ok(:final value) => value,
      Err(failure: SecretAlreadyExistsFailure(:final id)) =>
        switch (await secrets.fetch(id)) {
          Ok(:final value) => value,
          Err(:final failure) => fail('fetch: ${failure.runtimeType}'),
        },
      Err(:final failure) => fail('import: ${failure.runtimeType}'),
    };
  });

  tearDownAll(() async {
    if (scratch.existsSync()) await scratch.delete(recursive: true);
  });

  // What bwk reports for bwk-dart's fixture descriptors: the silent payment
  // address and the first taproot receive address it hands out. Null where
  // bwk-dart has no fixture: the account must open, with the network's
  // address prefix.
  const networks = <BitcoinNetwork, (bwk.SpNetwork, String?, String?, String)>{
    BitcoinNetwork.mainnet: (
      bwk.SpNetwork.bitcoin,
      'sp1qqfqnnv8czppwysafq3uwgwvsc638hc8rx3hscuddh0xa2yd746s7xqh6yy9ncjnqhqx'
          'azct0fzh98w7lpkm5fvlepqec2yy0sxlq4j6ccc3h6t0g',
      'bc1p4qhjn9zdvkux4e44uhx8tc55attvtyu358kutcqkudyccelu0was9fqzwh',
      'sp1q',
    ),
    BitcoinNetwork.testnet: (bwk.SpNetwork.testnet, null, null, 'tsp1q'),
    BitcoinNetwork.signet: (bwk.SpNetwork.signet, null, null, 'tsp1q'),
    BitcoinNetwork.regtest: (
      bwk.SpNetwork.regtest,
      'sprt1qqdpels3srq45dlezqvk20t3dlueftry6p5thc7msjm0s6jm3g84jzq5rxzzunfck6'
          'd45va2jcqxk429agt3e4klf3vzmcgp3zqthryhhqgpppjsp',
      'bcrt1p90h6z3p36n9hrzy7580h5l429uwchyg8uc9sz4jwzhdtuhqdl5eqkcyx0f',
      'sprt1q',
    ),
  };

  for (final MapEntry(
        key: network,
        value: (spNetwork, spAddress, taprootAddress, prefix),
      )
      in networks.entries) {
    testWidgets('${network.name}: bwk opens a watch-only account from the '
        'scan credential and reports the BIP352 wallet', (_) async {
      final key = switch (await secret.derive.descriptors.silentPayment(
        network: network,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('scanKey: ${failure.runtimeType}'),
      };

      final account = await bwk.SpAccount.createFromDescriptors(
        name: 'from-descriptors',
        network: spNetwork,
        spDescriptor: key.sp,
        taprootDescriptor: key.taproot,
        // Never contacted: nothing here scans or syncs.
        blindbitUrl: 'http://127.0.0.1:1',
        electrumUrl: '',
        dataDir: (await scratch.createTemp('descriptors_')).path,
      );
      try {
        expect(account.spAddress(), spAddress ?? startsWith(prefix));
        if (taprootAddress != null) {
          expect(await account.newTaprootAddress(), taprootAddress);
        }
      } finally {
        await account.dispose();
      }
    });
  }
}
