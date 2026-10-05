import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
// The FFI entry point's interface, to observe the one call the public API
// makes into bwk without the native library, which `flutter test` cannot load.
// ignore: implementation_imports
import 'package:bull_sdk/src/rust/frb_generated.dart' show BullSdkApi;
import 'package:convert/convert.dart' as convert;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// `sign.silentPayment` through the public API: one call into bwk's stateless
/// signer, with the spend key and the BIP86 account xprv bwk-dart's own
/// fixtures derive for the published test mnemonic, the spend key wiped once
/// the call returns, and bwk's refusals reported by type alone.
void main() {
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
  final psbt = Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff, 0x01]);
  final api = _Api();
  late Secret secret;

  setUpAll(() async {
    BullSdk.initMock(api: api);
    FakeSecureStoragePlatform().install();
    secret = ok(
      await Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).import(words: words),
    );
  });

  setUp(api.reset);

  for (final (network, vector) in [
    (BitcoinNetwork.regtest, _regtest),
    (BitcoinNetwork.mainnet, _mainnet),
  ]) {
    test('${network.name}: lends bwk the spend key and the BIP86 account '
        'xprv for one call, and returns its signed PSBT', () async {
      api.signed = Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff, 0x02]);

      final signed = ok(
        await secret.sign.silentPayment(psbt, network: network),
      );

      expect(signed, api.signed);
      expect(api.calls, 1);
      expect(api.psbt, psbt);
      expect(api.spendAtCall, vector.spend);
      expect(api.xprv, vector.xprv);
      expect(
        api.bSpend,
        everyElement(0),
        reason: 'the spend key bytes are wiped once bwk returns',
      );
    });
  }

  test('a refusal from bwk is UseSecretFailure, carries none of its reason, '
      'and the spend key is wiped all the same', () async {
    api.error = const bwk.SpError.signing(reason: 'input 0 is not ours');

    final failure = err(
      await secret.sign.silentPayment(psbt, network: BitcoinNetwork.regtest),
    );

    expect(failure, isA<UseSecretFailure>());
    expect(failure.logMessage, isNot(contains('input 0')));
    expect(api.calls, 1);
    expect(api.bSpend, everyElement(0));
  });

  test('a seed-only secret is refused before bwk is called', () async {
    FakeSecureStoragePlatform(
      entries: {
        'seed_aabbccdd': jsonEncode({
          'bytes': List<int>.filled(64, 7),
          'runtimeType': 'bytes',
        }),
      },
    ).install();
    final seedOnly = ok(
      await Secrets(
        scratchDirectory: () async => Directory.systemTemp.path,
      ).fetch(Fingerprint('aabbccdd')),
    );

    final failure = err(
      await seedOnly.sign.silentPayment(psbt, network: BitcoinNetwork.regtest),
    );

    expect(failure, isA<MnemonicRequiredFailure>());
    expect(api.calls, 0);
  });
}

/// bwk-dart's fixture derivation of the spend authority for the published
/// test mnemonic (`derive` in rust/tests/common/mod.rs, rust-bitcoin
/// directly): `b_spend` at m/352'/coin'/0'/0'/0 and the xprv of m/86'/coin'/0'.
const _regtest = (
  spend: '9fd37137e760930c7208fa905e991c78c522689d237a220b2820c3ddb4c745a8',
  xprv:
      'tprv8gytrHbFLhE7zLJ6BvZWEDDGJe8aS8VrmFnvqpMv8CEZtUbn2NY5KoRKQNpkcL1yniyC'
      'BRi7dAPy4kUxHkcSvd9jzLmLMEG96TPwant2jbX',
);
const _mainnet = (
  spend: 'c88567742d5019d7ccc81f6e82cef8ef01997a6a3761cc9166036b580549539b',
  xprv:
      'xprv9xgqHN7yz9MwCkxsBPN5qetuNdQSUttZNKw1dcYTV4mkaAFiBVGQziHs3NRSWMkCzvgj'
      'Ee3n9xV8oYywvM8at9yRqyaZVz6TYYhX98VjsUk',
);

/// Stands in for the FFI entry point: answers bwk's silent payments signer
/// only, and records what it was lent.
final class _Api implements BullSdkApi {
  int calls = 0;
  List<int>? psbt;
  List<int>? bSpend;
  String? spendAtCall;
  String? xprv;
  Uint8List? signed;
  Object? error;

  void reset() {
    calls = 0;
    psbt = bSpend = spendAtCall = xprv = signed = error = null;
  }

  @override
  Future<Uint8List> dartBwkApiSpSignerSignSilentPaymentPsbt({
    required List<int> psbt,
    required List<int> bSpend,
    String? taprootAccountXprv,
  }) async {
    calls++;
    this.psbt = List.of(psbt);
    this.bSpend = bSpend;
    spendAtCall = convert.hex.encode(bSpend);
    xprv = taprootAccountXprv;
    final failure = error;
    if (failure != null) throw failure;
    return signed!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}
