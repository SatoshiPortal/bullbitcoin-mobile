import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/signer_adapter.dart';
import 'package:secrets/src/data/adapters/swap_signer_adapter.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/psbt.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';
import 'package:secrets/src/domain/value_objects/swap_request.dart';

import 'fake_secure_key_value_store.dart';

// COVERAGE NOTE (audit item: SignerAdapter PSBT/PSET fact-extraction).
//
// The native extraction inside SignerAdapter.signBitcoinPsbt — bdkPsbt
// .extractTx(), wallet.isMine(...) ownership tagging, nonWitnessUtxo prev-out
// resolution, the `inputScriptPubKeys.length != txInputs.length` refuse guard,
// and the bdkPsbt.fee() u64-wrap guard — runs entirely against bdk_dart / LWK
// FFI types (bdk.Wallet, bdk.Psbt, bdk.Script). Those require the native
// rust libraries and are NOT loadable in a host `flutter test` process, and the
// extraction is inline (not factored behind an injectable seam), so the exact
// FFI calls cannot be faked here without a device/integration harness.
//
// What IS testable — and what these tests pin — is the SECURITY DECISION the
// adapter delegates to after extraction: it builds a TxFacts from the attacker-
// controlled PSBT and hands it to IntentValidator.validate (the gate it must
// refuse to sign on). These tests reconstruct the TxFacts each adversarial
// extraction would produce and assert the gate's verdict, plus the pure
// fee-cap helper the adapter calls on the Liquid path. The native call wiring
// itself is covered by integration tests on a device (out of scope here).

const _recipient = Output(scriptPubKey: 'recipient_spk', amountSat: 100000);
const _change = Output(scriptPubKey: 'my_change_spk', amountSat: 49000);
const _attacker = Output(scriptPubKey: 'attacker_spk', amountSat: 49000);

bool _ownsMyChange(String spk) => spk == 'my_change_spk';

const _send = SendIntent(
  outputs: [_recipient],
  maxFeeSat: 2000,
);

SecretsFailure _err(Result<void, SecretsFailure> r) =>
    (r as Err<void, SecretsFailure>).failure;
bool _isOk(Result<void, SecretsFailure> r) => r is Ok;

void main() {
  group('extracted TxFacts → IntentValidator gate (the signer\'s decision)', () {
    test('happy path: owned input + recipient + owned change within cap signs',
        () {
      // What the extractor produces for a clean wallet send.
      final facts = const TxFacts(
        outputs: [_recipient, _change],
        feeSat: 1000,
        inputScriptPubKeys: ['my_change_spk'],
      );
      final r = IntentValidator.validate(_send, facts,
          ownsScript: _ownsMyChange);
      expect(_isOk(r), isTrue);
    });

    test('foreign / non-wallet input → refuse to sign', () {
      // isMine() tagged one input as NOT ours: the gate must refuse.
      final facts = const TxFacts(
        outputs: [_recipient, _change],
        feeSat: 1000,
        inputScriptPubKeys: ['my_change_spk', 'foreign_spk'],
      );
      final r = IntentValidator.validate(_send, facts,
          ownsScript: _ownsMyChange);
      expect(_err(r), isA<SigningFailure>());
    });

    test('unresolved prev-out → empty input scripts → fail-closed refuse', () {
      // The adapter\'s `inputScriptPubKeys.length != txInputs.length` guard
      // drops unresolved inputs; if NONE resolve the validator sees an empty
      // list and (item 8) must fail closed rather than vacuously pass.
      final facts = const TxFacts(
        outputs: [_recipient, _change],
        feeSat: 1000,
        inputScriptPubKeys: [],
      );
      final r = IntentValidator.validate(_send, facts,
          ownsScript: _ownsMyChange);
      expect(_err(r), isA<SigningFailure>());
    });

    test('exfiltration output mis-present (not owned, not declared) → refuse',
        () {
      final facts = const TxFacts(
        outputs: [_recipient, _attacker],
        feeSat: 500,
        inputScriptPubKeys: ['my_change_spk'],
      );
      final r = IntentValidator.validate(_send, facts,
          ownsScript: _ownsMyChange);
      expect(_err(r), isA<SigningFailure>());
    });

    test('over-cap fee → refuse (the trustWitnessUtxo inflation footgun)', () {
      final facts = const TxFacts(
        outputs: [_recipient, _change],
        feeSat: 999999,
        inputScriptPubKeys: ['my_change_spk'],
      );
      final r = IntentValidator.validate(_send, facts,
          ownsScript: _ownsMyChange);
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('Liquid decision: validateLiquid on extracted (blinded) facts', () {
    // The adapter extracts fee + unblinded output scripts + locktime from the
    // PSET and hands them to IntentValidator.validateLiquid. These pin the
    // decision the adapter delegates (the native extraction itself is
    // device-only, per the coverage note above).
    test('within cap + recipient script present proceeds', () {
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(
          feeSat: 1500,
          outputScriptPubKeys: ['recipient_spk', 'my_change_spk', ''],
        ),
      );
      expect(_isOk(r), isTrue);
    });

    test('over cap (incl. out-of-range overpay) refuses', () {
      expect(
        _err(IntentValidator.validateLiquid(_send,
            const LiquidFacts(feeSat: 999999, outputScriptPubKeys: ['recipient_spk']))),
        isA<SigningFailure>(),
      );
      expect(
        _err(IntentValidator.validateLiquid(
            _send,
            const LiquidFacts(
                feeSat: 2100000000000000,
                outputScriptPubKeys: ['recipient_spk']))),
        isA<SigningFailure>(),
      );
    });

    test('address substitution (recipient script absent) refuses', () {
      expect(
        _err(IntentValidator.validateLiquid(_send,
            const LiquidFacts(feeSat: 10, outputScriptPubKeys: ['attacker_spk', '']))),
        isA<SigningFailure>(),
      );
    });
  });

  // These construct the REAL adapters and exercise the passphrase-rejection
  // branch, which returns BEFORE any lwk/boltz FFI call (the mnemonic decode +
  // `hasPassphrase` check are pure Dart). This pins the M2 fix — a passphrase
  // wallet must be refused, never silently signed/derived under the DIFFERENT
  // bare-seed wallet — so deleting the guard makes these go red.
  group('adapter passphrase rejection (real adapter; returns before FFI)', () {
    const fpHex = 'deadbeef';

    // A stored mnemonic WITH a passphrase (words need not be a valid checksum —
    // `hasPassphrase` does not derive a seed).
    Uint8List passphraseBlob() => Uint8List.fromList(utf8.encode(jsonEncode({
          'kind': 'mnemonic',
          'words': const [
            'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
            'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
          ],
          'passphrase': 'trezor',
          'language': 'english',
        })));

    Future<FssSecretStoreAdapter> storeWithPassphraseSeed() async {
      final store = FssSecretStoreAdapter(FakeSecureKeyValueStore(),
          initialRetryDelay: Duration.zero);
      await store.store(SecretStoreKeys.seedKey(fpHex), passphraseBlob());
      return store;
    }

    void expectSigningErr<T>(Result<T, SecretsFailure> r) {
      switch (r) {
        case Err(:final failure):
          expect(failure, isA<SigningFailure>());
        case Ok():
          fail('expected Err(SigningFailure), got Ok');
      }
    }

    test('signLiquidPset REFUSES a passphrase wallet (lwk uses the bare seed)',
        () async {
      final adapter = SignerAdapter(await storeWithPassphraseSeed());
      final r = await adapter.signLiquidPset(
        fingerprint: Fingerprint(fpHex),
        pset: Psbt('cHNldA=='),
        intent: _send,
        isTestnet: true,
      );
      expectSigningErr(r);
    });

    test('createBtcReverse REFUSES a passphrase wallet (boltz uses the bare seed)',
        () async {
      final adapter = SwapSignerAdapter(await storeWithPassphraseSeed());
      final r = await adapter.createBtcReverse(
        fingerprint: Fingerprint(fpHex),
        index: 0,
        request: const ReverseSwapRequest(requestedReceiveSat: 50000),
        electrumUrl: 'electrum.example',
        boltzUrl: 'boltz.example',
        isTestnet: true,
      );
      expectSigningErr(r);
    });
  });
}
