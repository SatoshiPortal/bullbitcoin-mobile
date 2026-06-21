import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/intent_validation.dart';
import 'package:secrets/src/data/adapters/signer_adapter.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/descriptors.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

const _recipient = Output(scriptPubKey: 'recipient_spk', amountSat: 100000);
const _change = Output(scriptPubKey: 'my_change_spk', amountSat: 49000);
const _attacker = Output(scriptPubKey: 'attacker_spk', amountSat: 49000);

bool _ownsMyChange(String spk) => spk == 'my_change_spk';

final _send = SendIntent(
  outputs: const [_recipient],
  walletDescriptor: BitcoinDescriptor(external: 'ext', internal: 'int'),
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
        const TxFacts(outputs: [_recipient, _change], feeSat: 1000),
        ownsScript: _ownsMyChange,
      );
      expect(_isOk(r), isTrue);
    });

    test('REJECTS fee above the cap (closes trustWitnessUtxo inflation)', () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_recipient, _change], feeSat: 5000),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS an unexpected output not owned by the wallet (exfiltration)',
        () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_recipient, _attacker], feeSat: 500),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS change that the wallet does not own', () {
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_recipient, _change], feeSat: 500),
        ownsScript: (_) => false, // owns nothing
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS a DUPLICATED recipient output (amount-splitting / 2× pay)',
        () {
      // One recipient declared, but the tx pays it twice.
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_recipient, _recipient], feeSat: 500),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS when a declared output is MISSING from the tx', () {
      // Tx contains only owned change — the recipient was dropped.
      final r = IntentValidator.validate(
        _send,
        const TxFacts(outputs: [_change], feeSat: 500),
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

  group('SwapIntent commitment validation (untrusted Boltz address)', () {
    const reverse = SwapIntent(
      preimageHash: 'ph', claimPubkey: 'mykey', refundPubkey: 'boltzkey',
      timeout: 100, amountSat: 50000, direction: SwapDirection.reverse,
    );
    const submarine = SwapIntent(
      preimageHash: 'ph', claimPubkey: 'boltzkey', refundPubkey: 'mykey',
      timeout: 100, amountSat: 50000, direction: SwapDirection.submarine,
    );

    test('reverse: accepts when claim script + intent commit to our key', () {
      final r = IntentValidator.validateSwapCommitment(
        reverse,
        ownClaimPubkey: 'mykey',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
      );
      expect(_isOk(r), isTrue);
    });

    test('reverse: REJECTS when Boltz script uses a different claim key', () {
      final r = IntentValidator.validateSwapCommitment(
        reverse,
        ownClaimPubkey: 'mykey',
        scriptReceiverPubkey: 'attackerkey', // not ours
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('submarine: accepts when refund script + intent commit to our key', () {
      final r = IntentValidator.validateSwapCommitment(
        submarine,
        ownRefundPubkey: 'mykey',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'ph',
      );
      expect(_isOk(r), isTrue);
    });

    test('submarine: REJECTS a hashlock that differs from the intent', () {
      final r = IntentValidator.validateSwapCommitment(
        submarine,
        ownRefundPubkey: 'mykey',
        scriptReceiverPubkey: 'boltzkey',
        scriptSenderPubkey: 'mykey',
        scriptHashlock: 'WRONG',
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('chain: requires BOTH claim and refund keys to commit', () {
      const chain = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'ck', refundPubkey: 'rk',
        timeout: 1, amountSat: 1, direction: SwapDirection.chain,
      );
      final ok = IntentValidator.validateSwapCommitment(
        chain,
        ownClaimPubkey: 'ck',
        ownRefundPubkey: 'rk',
        scriptReceiverPubkey: 'ck',
        scriptSenderPubkey: 'rk',
        scriptHashlock: 'ph',
      );
      expect(_isOk(ok), isTrue);
      final bad = IntentValidator.validateSwapCommitment(
        chain,
        ownClaimPubkey: 'ck',
        ownRefundPubkey: 'rk',
        scriptReceiverPubkey: 'ck',
        scriptSenderPubkey: 'attacker', // refund side tampered
        scriptHashlock: 'ph',
      );
      expect(_err(bad), isA<SigningFailure>());
    });

    test('chain btcToLbtc: validates refund on BTC lockup + claim on LBTC claim',
        () {
      const chain = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'myclaim', refundPubkey: 'myrefund',
        timeout: 1, amountSat: 1, direction: SwapDirection.chain,
      );
      // btcToLbtc: BTC = lockup (our refund = sender), LBTC = claim (our claim
      // = receiver).
      final ok = IntentValidator.validateChainSwapCommitment(
        chain,
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        // BTC = lockup: its locktime must match the intent timeout (1).
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 1),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999), // claim leg locktime is not bound
      );
      expect(_isOk(ok), isTrue);

      // The LBTC (claim) leg is REALLY validated: tamper it → reject.
      final tampered = IntentValidator.validateChainSwapCommitment(
        chain,
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 1),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'attacker',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(tampered), isA<SigningFailure>());
    });

    test('chain: REJECTS when the LOCKUP leg locktime != intent timeout', () {
      const chain = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'myclaim', refundPubkey: 'myrefund',
        timeout: 100, amountSat: 1, direction: SwapDirection.chain,
      );
      final r = IntentValidator.validateChainSwapCommitment(
        chain,
        direction: ChainDirection.btcToLbtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        // BTC lockup leg locktime (50) pushed away from the intended 100.
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 50),
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999),
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('single leg: REJECTS a script locktime that differs from the intent',
        () {
      final r = IntentValidator.validateSwapCommitment(
        reverse, // timeout: 100
        ownClaimPubkey: 'mykey',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
        scriptLocktime: 777, // server pushed the refund window out
        expectedLocktime: 100,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('single leg: accepts a matching script locktime', () {
      final r = IntentValidator.validateSwapCommitment(
        reverse, // timeout: 100
        ownClaimPubkey: 'mykey',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'boltzkey',
        scriptHashlock: 'ph',
        scriptLocktime: 100,
        expectedLocktime: 100,
      );
      expect(_isOk(r), isTrue);
    });

    test('chain lbtcToBtc: legs swap chains (BTC claim / LBTC lockup)', () {
      const chain = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'myclaim', refundPubkey: 'myrefund',
        timeout: 1, amountSat: 1, direction: SwapDirection.chain,
      );
      final ok = IntentValidator.validateChainSwapCommitment(
        chain,
        direction: ChainDirection.lbtcToBtc,
        ownClaimPubkey: 'myclaim',
        ownRefundPubkey: 'myrefund',
        btcScript: const SwapScriptLeg(
            receiverPubkey: 'myclaim',
            senderPubkey: 'server',
            hashlock: 'ph',
            locktime: 999), // claim leg, not bound
        // LBTC = lockup here: its locktime must match the intent timeout (1).
        lbtcScript: const SwapScriptLeg(
            receiverPubkey: 'server',
            senderPubkey: 'myrefund',
            hashlock: 'ph',
            locktime: 1),
      );
      expect(_isOk(ok), isTrue);
    });

    test('REJECTS when no own key is supplied', () {
      final r = IntentValidator.validateSwapCommitment(
        reverse,
        scriptReceiverPubkey: 'x',
        scriptSenderPubkey: 'y',
        scriptHashlock: 'ph',
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('reverse: REJECTS when intent.claimPubkey disagrees with our key', () {
      const badIntent = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'someoneelse', refundPubkey: 'b',
        timeout: 1, amountSat: 1, direction: SwapDirection.reverse,
      );
      final r = IntentValidator.validateSwapCommitment(
        badIntent,
        ownClaimPubkey: 'mykey',
        scriptReceiverPubkey: 'mykey',
        scriptSenderPubkey: 'b',
        scriptHashlock: 'ph',
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('PayjoinIntent validation (BIP78 sender checklist)', () {
    final pj = PayjoinIntent(
      originalInputs: const ['outpoint_a'],
      originalOutputs: const [_recipient],
      originalVersion: 2,
      originalLockTime: 0,
      maxFeeContributionSat: 1000,
    );

    test('accepts when originals preserved and extra fee bounded', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient, _change],
          feeSat: 800,
          version: 2,
          lockTime: 0,
          inputOutpoints: ['outpoint_a', 'outpoint_b'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_isOk(r), isTrue);
    });

    test('REJECTS a changed version', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient],
          feeSat: 0,
          version: 1,
          lockTime: 0,
          inputOutpoints: ['outpoint_a'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('FAILS CLOSED when version/locktime facts are missing (null)', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient],
          feeSat: 0,
          // version & lockTime intentionally null (extractor couldn't confirm)
          inputOutpoints: ['outpoint_a'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS a dropped original input', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient],
          feeSat: 0,
          version: 2,
          lockTime: 0,
          inputOutpoints: ['outpoint_b'], // original 'outpoint_a' gone
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS an altered original output', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_attacker],
          feeSat: 0,
          version: 2,
          lockTime: 0,
          inputOutpoints: ['outpoint_a'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS excess fee contribution', () {
      final r = IntentValidator.validate(
        pj,
        const TxFacts(
          outputs: [_recipient],
          feeSat: 5000,
          version: 2,
          lockTime: 0,
          inputOutpoints: ['outpoint_a'],
        ),
        ownsScript: _ownsMyChange,
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('SwapIntent validation (untrusted Boltz address)', () {
    const swap = SwapIntent(
      preimageHash: 'ph',
      claimPubkey: 'claim',
      refundPubkey: 'refund',
      timeout: 100,
      amountSat: 50000,
      direction: SwapDirection.reverse,
    );

    test('accepts when the lockup address matches our own derived script', () {
      final r = IntentValidator.validate(
        swap,
        const TxFacts(outputs: [], feeSat: 0, lockupScriptAddress: 'addr_ours'),
        ownsScript: (_) => false,
        reconstructLockupAddress: (_) => 'addr_ours',
      );
      expect(_isOk(r), isTrue);
    });

    test('REJECTS a Boltz address that does not commit to our key', () {
      final r = IntentValidator.validate(
        swap,
        const TxFacts(
            outputs: [], feeSat: 0, lockupScriptAddress: 'addr_boltz_evil'),
        ownsScript: (_) => false,
        reconstructLockupAddress: (_) => 'addr_ours',
      );
      expect(_err(r), isA<SigningFailure>());
    });

    test('REJECTS when there is no lockup output', () {
      final r = IntentValidator.validate(
        swap,
        const TxFacts(outputs: [], feeSat: 0),
        ownsScript: (_) => false,
        reconstructLockupAddress: (_) => 'addr_ours',
      );
      expect(_err(r), isA<SigningFailure>());
    });
  });

  group('Liquid fee-cap (sound under confidential outputs)', () {
    test('SendIntent: accepts fee within cap, rejects above', () {
      expect(SignerAdapter.debugValidateLiquidFee(_send, 1500), isNull);
      expect(SignerAdapter.debugValidateLiquidFee(_send, 9999),
          isA<SigningFailure>());
    });

    test('SwapIntent is refused on the generic Liquid PSET path', () {
      const swap = SwapIntent(
        preimageHash: 'ph', claimPubkey: 'c', refundPubkey: 'r',
        timeout: 1, amountSat: 1, direction: SwapDirection.reverse,
      );
      expect(SignerAdapter.debugValidateLiquidFee(swap, 0),
          isA<SigningFailure>());
    });
  });
}
