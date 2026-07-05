import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

const _recipient = Output(scriptPubKey: 'recipient_spk', amountSat: 100000);
const _change = Output(scriptPubKey: 'my_change_spk', amountSat: 49000);
const _attacker = Output(scriptPubKey: 'attacker_spk', amountSat: 49000);

bool _ownsMyChange(String spk) => spk == 'my_change_spk';

const _send = SendIntent(
  outputs: [_recipient],
  maxFeeSat: 2000,
);

bool _isOk(Result<void, SecretsFailure> r) => r is Ok;
SecretsFailure _err(Result<void, SecretsFailure> r) =>
    (r as Err<void, SecretsFailure>).failure;

void main() {
  group('SendIntent validation (#1703 gate)', () {
    test('accepts recipient + owned change within fee cap', () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 1000,
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_isOk(r), isTrue);
    });

    test('REJECTS (fail-closed) a send with zero known input scripts', () {
      // An empty inputScriptPubKeys means the extractor vouched for NO input;
      // the per-input ownership loop would vacuously pass, so we must refuse.
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_recipient, _change], feeSat: 1000),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS fee above the cap (closes trustWitnessUtxo inflation)', () {
      // Inputs are valid + owned and outputs are all accounted for, so the ONLY
      // thing wrong is the fee — deleting the fee-cap check makes this go red
      // (previously an empty inputScriptPubKeys made it green via the
      // empty-inputs guard, so it did not uniquely pin the cap).
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 5000,
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS an unexpected output not owned by the wallet (exfiltration)',
        () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _attacker],
          feeSat: 500,
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS change that the wallet does not own (change branch)', () {
      // The INPUT is owned (so the input-ownership loop passes) but the change
      // output is NOT owned — this must trip the OUTPUT branch specifically, not
      // the input check. `_change` is not a declared recipient and not owned →
      // "unexpected output not owned".
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 500,
          inputScriptPubKeys: ['my_input_spk'],
        ),
        ownsScript: (spk) => spk == 'my_input_spk', // owns the input, NOT change
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS a DUPLICATED recipient output (amount-splitting / 2× pay)',
        () {
      // One recipient declared, but the tx pays it twice.
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _recipient],
          feeSat: 500,
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS when a declared output is MISSING from the tx', () {
      // Tx contains only owned change — the recipient was dropped.
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_change],
          feeSat: 500,
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('accepts when all inputs are wallet-owned', () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 500,
          inputScriptPubKeys: ['my_change_spk', 'my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_isOk(r), isTrue);
    });

    test('REJECTS a send that spends a non-wallet input (coin-control)', () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 500,
          inputScriptPubKeys: ['my_change_spk', 'foreign_input_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('swap commitment validation (built from the SDK swap, not the caller)',
      () {
    // Reverse: WE claim → our key is the RECEIVER; amount is exact.
    test('reverse: accepts when the claim script commits to our key + preimage',
        () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: true,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
        outAmountSat: 50000,
        exactSat: 50000,
      );
      expect(_isOk(r), isTrue);
    });

    test('reverse: REJECTS a Boltz amount that differs from the requested', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: true,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
        outAmountSat: 40000, // under-pays the reverse
        exactSat: 50000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('reverse: REJECTS when the script uses a different receiver key', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: true,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'attackerkey', // not ours
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
        outAmountSat: 50000,
        exactSat: 50000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('reverse: REJECTS a hashlock that is not our preimage', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: true,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'WRONG',
        outAmountSat: 50000,
        exactSat: 50000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    // Submarine: WE refund → our key is the SENDER; amount is a lockup range.
    test('submarine: accepts a lockup within [invoice, maxLockup]', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'ph',
        outAmountSat: 50500, // invoice 50000 + boltz fee 500
        minSat: 50000,
        maxSat: 51000,
      );
      expect(_isOk(r), isTrue);
    });

    test('submarine: REJECTS a lockup below the invoice floor', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'ph',
        outAmountSat: 49000, // below invoice 50000
        minSat: 50000,
        maxSat: 51000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('submarine: REJECTS a lockup above the caller ceiling (over-charge)',
        () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'ph',
        outAmountSat: 60000, // above maxLockup 51000
        minSat: 50000,
        maxSat: 51000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('submarine: REJECTS when the sender (refund) script key is not ours',
        () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'attackerkey', // our refund side tampered
        scriptHashlock: 'ph',
        outAmountSat: 50500,
        minSat: 50000,
        maxSat: 51000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('submarine: REJECTS a hashlock that is not our preimage', () {
      final r = IntentValidator.validateSwapCommitment(
        weAreReceiver: false,
        ownPubkey: 'mykey',
        preimageSha256: 'ph',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'WRONG',
        outAmountSat: 50500,
        minSat: 50000,
        maxSat: 51000,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    // Chain: commits to BOTH keys across two legs; both hashlock our preimage.
    test('chain btcToLbtc: refund on BTC lockup + claim on LBTC claim', () {
      final ok = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_isOk(ok), isTrue);

      // The claim leg is REALLY validated: tamper its receiver key → reject.
      final tampered = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'attacker',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(tampered), isA<SigningFailure>());
    });

    test('chain: REJECTS when the lockup (refund) key is tampered', () {
      final r = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'attacker', // lockup refund side tampered
            hashlock: 'ph',
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('chain: REJECTS a lockup-leg hashlock that is not our preimage', () {
      final r = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'WRONG', // lockup leg hashlock tampered
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('chain: REJECTS a claim-leg hashlock that is not our preimage', () {
      final r = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'WRONG', // claim leg hashlock tampered
            locktime: 999),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('chain: REJECTS a send amount that differs from the request', () {
      final r = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 2000, // server quoted a different lockup
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 111),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('chain lbtcToBtc: legs swap chains (LBTC lockup / BTC claim)', () {
      final ok = IntentValidator.validateChainSwapCommitment(
        direction: ChainDirection.lbtcToBtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        preimageSha256: 'ph',
        outAmountSat: 1000,
        sendAmountSat: 1000,
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim', // BTC = claim leg now
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'server', // LBTC = lockup leg now
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 111),
      );
      expect(_isOk(ok), isTrue);
    });

    test('checkSwapAmount: rejects a negative/out-of-range amount', () {
      expect(_err(IntentValidator.checkSwapAmount(outAmountSat: -1)),
          isA<SigningFailure>());
      expect(
          _err(IntentValidator.checkSwapAmount(
              outAmountSat: 2100000000000001)),
          isA<SigningFailure>());
    });

    test('checkSwapAmount: FAILS CLOSED with NO bound (exact/min/max all null)',
        () {
      // An all-null call would otherwise vacuously pass and green-light any
      // in-range amount — contradicting the fail-closed doctrine.
      final r = IntentValidator.checkSwapAmount(outAmountSat: 50000);
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('PayjoinIntent is HARD-REJECTED until payjoin is wired', () {
    // The full BIP78 sender checklist is subtle (reject wallet-owned
    // receiver-added inputs, gate every extra output, allow the receiver's own
    // output amount increase) and is not exercisable today — the signer never
    // populates inputOutpoints and no caller constructs a PayjoinIntent. A
    // PARTIAL validator is itself a theft vector (the audit merge-blocker), so
    // BOTH signing entry points refuse a PayjoinIntent outright (fail-closed).
    final pj = PayjoinIntent(
      originalInputs: const ['outpoint_a'],
      originalOutputs: const [_recipient],
      originalVersion: 2,
      originalLockTime: 0,
      maxFeeContributionSat: 1000,
    );

    test('validate() refuses to sign a PayjoinIntent (even a well-formed one)',
        () {
      // Every fact here would satisfy a naive checklist (originals present,
      // version/locktime unchanged, fee bounded) — it is refused anyway.
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 800,
          version: 2,
          lockTime: 0,
          inputOutpoints: ['outpoint_a', 'outpoint_b'],
          inputScriptPubKeys: ['my_change_spk'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('validateLiquid() refuses to sign a PayjoinIntent', () {
      final r = IntentValidator.validateLiquid(
        pj,
        const LiquidFacts(
          feeSat: 100,
          outputScriptPubKeys: ['recipient_spk', ''],
          lockTime: 0,
        ),
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('Liquid validation (blinded amounts; scripts + fee are checkable)', () {
    test('SendIntent: accepts fee within cap when the recipient script present',
        () {
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(
          feeSat: 1500,
          // recipient script + a change script + the empty fee output
          outputScriptPubKeys: ['recipient_spk', 'my_change_spk', ''],
          lockTime: 0,
        ),
      );
      expect(_isOk(r), isTrue);
    });

    test('SendIntent: REJECTS fee above the cap', () {
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(feeSat: 9999, outputScriptPubKeys: ['recipient_spk']),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('SendIntent: REJECTS address substitution (recipient script absent)',
        () {
      // The blinded amounts can't be checked, but the SCRIPTS aren't blinded —
      // a tx paying only the attacker's script is refused.
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(
            feeSat: 100, outputScriptPubKeys: ['attacker_spk', '']),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('SendIntent: FAILS CLOSED when no output scripts can be extracted', () {
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(feeSat: 100, outputScriptPubKeys: []),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS a negative (u64-wrapped) fee', () {
      final r = IntentValidator.validateLiquid(
        _send,
        const LiquidFacts(feeSat: -1, outputScriptPubKeys: ['recipient_spk']),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('SendIntent: FAILS CLOSED when the intent declares NO outputs', () {
      // With no declared recipients the multiset loop is vacuous — on Liquid
      // (blinded amounts, no ownership check) that would let ALL value leave
      // within the fee cap. The Bitcoin path fails closed via input ownership;
      // Liquid must reject an empty-outputs intent outright.
      const emptySend = SendIntent(outputs: [], maxFeeSat: 2000);
      final r = IntentValidator.validateLiquid(
        emptySend,
        const LiquidFacts(
            feeSat: 100, outputScriptPubKeys: ['attacker_spk', '']),
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('Output construction guard', () {
    test('REJECTS an empty scriptPubKey (would match the Liquid fee output)',
        () {
      expect(
        () => Output(scriptPubKey: '', amountSat: 1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
