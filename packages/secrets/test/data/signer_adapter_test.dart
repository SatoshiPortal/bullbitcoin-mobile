import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/adapters/signer_adapter.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

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

final _send = SendIntent(
  outputs: const [_recipient],
  walletDescriptor: BitcoinDescriptor(external: 'ext', internal: 'int'),
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

  group('Liquid fee-cap helper (the only pure seam in the PSET path)', () {
    test('within cap proceeds; over cap (incl. out-of-range overpay) refuses',
        () {
      expect(SignerAdapter.debugValidateLiquidFee(_send, 1500), isNull);
      expect(SignerAdapter.debugValidateLiquidFee(_send, 999999),
          isA<SigningFailure>());
      expect(SignerAdapter.debugValidateLiquidFee(_send, 2100000000000000),
          isA<SigningFailure>());
    });

    test('a SwapIntent is refused on the generic PSET path', () {
      const swap = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'c', refundPubkey: 'r',
        timeout: 1, amountSat: 1, direction: SwapDirection.reverse,
      );
      expect(SignerAdapter.debugValidateLiquidFee(swap, 0),
          isA<SigningFailure>());
    });
  });
}
