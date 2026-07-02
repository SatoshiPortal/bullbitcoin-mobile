import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

/// The largest plausible amount (21M BTC in sats). Any fee/amount at or beyond
/// this — or negative — is treated as out-of-range and rejected (fail closed),
/// so a u64→signed-int wrap can never slip under a positive cap.
const int _maxMoneySat = 2100000000000000;

/// The facts a signer extracts from the decoded PSBT (via BDK) and feeds to the
/// validator. Separating extraction (native) from the DECISION (pure) is what
/// makes the security gate unit-testable.
class TxFacts {
  const TxFacts({
    required this.outputs,
    required this.feeSat,
    this.version,
    this.lockTime,
    this.inputOutpoints = const [],
    this.inputScriptPubKeys = const [],
  });

  final List<Output> outputs;
  final int feeSat;
  final int? version;
  final int? lockTime;
  final List<String> inputOutpoints;

  /// The scriptPubKey of every input's prev-out (from each PSBT input's
  /// witness/non-witness UTXO). A plain send must spend ONLY wallet-owned
  /// inputs; this lets the validator enforce that.
  final List<String> inputScriptPubKeys;
}

/// The facts a signer extracts from a decoded Liquid PSET (via LWK). Liquid
/// output amounts and assets are CONFIDENTIAL (blinded) and cannot be checked;
/// the network fee and the output SCRIPTS are NOT blinded, so those are the only
/// facts the validator can soundly gate on.
class LiquidFacts {
  const LiquidFacts({
    required this.feeSat,
    required this.outputScriptPubKeys,
    this.lockTime,
  });

  final int feeSat;

  /// The scriptPubKey (hex) of every output, unblinded. The explicit fee output
  /// carries an empty script.
  final List<String> outputScriptPubKeys;
  final int? lockTime;
}

/// One swap redeem-script's relevant pubkeys + hashlock + locktime (a BTC or
/// LBTC leg), as returned by the Boltz SDK.
class SwapScriptLeg {
  const SwapScriptLeg({
    required this.receiverPubkey,
    required this.senderPubkey,
    required this.hashlock,
    required this.locktime,
  });
  final String receiverPubkey;
  final String senderPubkey;
  final String hashlock;

  /// The CLTV timeout block in the redeem script. Boltz chooses it, so the
  /// caller cannot know it before creation — it is SURFACED on `CreatedSwap`
  /// (`lockupLocktime`) for the app to inspect, not gated here.
  final int locktime;
}

/// Pure validation of signing intents and swap commitments. A signer MUST call
/// the relevant method and refuse to sign / return `Err` on failure — BDK/LWK
/// sign blindly (#1703) and the Boltz-supplied address is untrusted.
class IntentValidator {
  // ── Bitcoin PSBT signing ──────────────────────────────────────────────────

  /// [ownsScript] decides whether a scriptPubKey belongs to the signing wallet
  /// (so change is provably owned). The signer supplies it from the wallet
  /// descriptor.
  static Result<void, SecretsFailure> validate(
    SigningIntent intent,
    TxFacts facts, {
    required bool Function(String scriptPubKey) ownsScript,
  }) {
    return switch (intent) {
      SendIntent() => _validateSend(intent, facts, ownsScript),
      PayjoinIntent() => _validatePayjoin(intent, facts),
    };
  }

  static Result<void, SecretsFailure> _validateSend(
    SendIntent intent,
    TxFacts facts,
    bool Function(String) ownsScript,
  ) {
    // A negative fee (u64 wrap) or an absurd one is refused outright — the pure
    // gate must never green-light either even if an adapter forgets to guard.
    if (facts.feeSat < 0 || facts.feeSat > _maxMoneySat) {
      return Err(SigningFailure('fee ${facts.feeSat} out of range'));
    }
    if (facts.feeSat > intent.maxFeeSat) {
      return Err(SigningFailure(
          'fee ${facts.feeSat} exceeds cap ${intent.maxFeeSat}'));
    }
    // Fail CLOSED on zero known input scripts: a real send always has
    // resolvable inputs, so an empty list means the extractor could not vouch
    // for ANY input — the per-input ownership loop below would then vacuously
    // pass. The adapter already refuses on a count mismatch; this is
    // defense-in-depth so the pure validator never green-lights a send it
    // cannot prove spends only owned coins.
    if (facts.inputScriptPubKeys.isEmpty) {
      return const Err(
          SigningFailure('send has no resolvable input scripts to validate'));
    }
    // Every input of a plain send must be a wallet-owned UTXO. This closes the
    // "extra/foreign input pulled in" vector (a send spends only your coins);
    // combined with the output check below, funds can only go to a declared
    // recipient or owned change. (Skipped for payjoin, where the receiver
    // legitimately contributes inputs.)
    for (final spk in facts.inputScriptPubKeys) {
      if (!ownsScript(spk)) {
        return const Err(SigningFailure('send spends a non-wallet input'));
      }
    }
    // Multiset match: each declared output must be present EXACTLY as declared
    // (matching count + amount), and any extra output must be owned change.
    // A Set+membership check (the naive form) would let a recipient output be
    // duplicated (pay 2×) or omitted entirely and still pass.
    final remaining = <String, int>{};
    for (final o in intent.outputs) {
      final key = '${o.scriptPubKey}:${o.amountSat}';
      remaining[key] = (remaining[key] ?? 0) + 1;
    }
    for (final out in facts.outputs) {
      final key = '${out.scriptPubKey}:${out.amountSat}';
      final left = remaining[key] ?? 0;
      if (left > 0) {
        remaining[key] = left - 1; // consume one declared output
      } else if (!ownsScript(out.scriptPubKey)) {
        // Neither a (still-unconsumed) declared recipient nor owned change:
        // an extra/duplicated/exfiltration output — refuse.
        return const Err(
            SigningFailure('unexpected output not owned by wallet'));
      }
    }
    // Every declared output must have been matched by the tx.
    if (remaining.values.any((c) => c > 0)) {
      return const Err(SigningFailure('a declared output is missing from the tx'));
    }
    return const Ok(null);
  }

  /// NOTE (integration): the only Bitcoin signer does not yet populate
  /// `facts.inputOutpoints`, so any non-empty `originalInputs` fails CLOSED here
  /// — payjoin is unusable until the extractor supplies outpoints in the same
  /// format the [PayjoinIntent] uses. Finalize before wiring payjoin.
  static Result<void, SecretsFailure> _validatePayjoin(
    PayjoinIntent intent,
    TxFacts facts,
  ) {
    if (facts.feeSat < 0 || facts.feeSat > _maxMoneySat) {
      return Err(SigningFailure('payjoin fee ${facts.feeSat} out of range'));
    }
    // Fail CLOSED: missing version/locktime facts mean the extractor couldn't
    // confirm they are unchanged, so we must refuse rather than skip the check.
    if (facts.version != intent.originalVersion) {
      return const Err(SigningFailure('payjoin version changed or unknown'));
    }
    if (facts.lockTime != intent.originalLockTime) {
      return const Err(SigningFailure('payjoin locktime changed or unknown'));
    }
    // Every original input the sender contributed must still be present.
    for (final inp in intent.originalInputs) {
      if (!facts.inputOutpoints.contains(inp)) {
        return const Err(SigningFailure('payjoin dropped an original input'));
      }
    }
    // Every original output the sender declared must still be present — as a
    // MULTISET (matching count), not a Set. A Set would let a receiver drop one
    // of two identical batched outputs (double-payment) and redirect its value:
    // the single remaining copy would satisfy both membership tests. `_validateSend`
    // was hardened to a multiset for exactly this; payjoin must match.
    final remaining = <String, int>{};
    for (final o in intent.originalOutputs) {
      final key = '${o.scriptPubKey}:${o.amountSat}';
      remaining[key] = (remaining[key] ?? 0) + 1;
    }
    for (final out in facts.outputs) {
      final key = '${out.scriptPubKey}:${out.amountSat}';
      final left = remaining[key] ?? 0;
      if (left > 0) remaining[key] = left - 1; // consume one original output
    }
    if (remaining.values.any((c) => c > 0)) {
      return const Err(SigningFailure('payjoin altered an original output'));
    }
    // BIP78: maxFeeContributionSat bounds the RECEIVER's additional fee, not
    // the total tx fee. The original tx already paid a fee; the receiver may
    // add up to maxFeeContributionSat MORE. Without the original fee amount
    // (not currently in TxFacts) we cannot bound the additional contribution
    // precisely — so we fail CLOSED (reject any total fee exceeding the cap)
    // until the extractor supplies the original fee. This is intentionally
    // stricter than BIP78: it never overpays, but may reject a legitimate
    // payjoin whose original fee alone exceeds maxFeeContributionSat. Fix by
    // carrying originalFeeSat in PayjoinIntent/TxFacts before wiring payjoin.
    if (facts.feeSat > intent.maxFeeContributionSat) {
      return Err(SigningFailure(
          'payjoin total fee ${facts.feeSat} exceeds contribution cap '
          '${intent.maxFeeContributionSat} (conservative bound — see comment)'));
    }
    return const Ok(null);
  }

  // ── Liquid PSET signing ───────────────────────────────────────────────────

  /// Validates a Liquid send on the UNBLINDABLE facts only. Amounts/assets are
  /// confidential, so this CANNOT prove per-output value or change ownership
  /// (documented residual, README SPEC §10). It DOES enforce the fee cap and
  /// that every declared recipient SCRIPT is present in the tx (blocking
  /// address substitution — the classic "sign my PSET, get your L-BTC" theft),
  /// and it FAILS CLOSED when no output scripts can be extracted.
  ///
  /// For a [PayjoinIntent] on Liquid (not currently wired) only the fee cap is
  /// enforced.
  static Result<void, SecretsFailure> validateLiquid(
    SigningIntent intent,
    LiquidFacts facts,
  ) {
    if (facts.feeSat < 0 || facts.feeSat > _maxMoneySat) {
      return Err(SigningFailure('liquid fee ${facts.feeSat} out of range'));
    }
    switch (intent) {
      case SendIntent(:final maxFeeSat, :final outputs):
        if (facts.feeSat > maxFeeSat) {
          return Err(SigningFailure(
              'liquid fee ${facts.feeSat} exceeds cap $maxFeeSat'));
        }
        // Fail CLOSED: if the extractor could not read any output script we
        // cannot vouch for the recipients — refuse rather than sign blind.
        if (facts.outputScriptPubKeys.isEmpty) {
          return const Err(SigningFailure(
              'liquid tx has no extractable output scripts to validate'));
        }
        // Every declared recipient script must be present (multiset over the
        // SCRIPTS only — amounts are blinded so cannot be matched). Extra
        // outputs (change/fee) are allowed since Liquid ownership isn't provable.
        final present = <String, int>{};
        for (final s in facts.outputScriptPubKeys) {
          present[s] = (present[s] ?? 0) + 1;
        }
        for (final o in outputs) {
          final left = present[o.scriptPubKey] ?? 0;
          if (left <= 0) {
            return const Err(SigningFailure(
                'liquid tx is missing a declared recipient script'));
          }
          present[o.scriptPubKey] = left - 1;
        }
        return const Ok(null);
      case PayjoinIntent(:final maxFeeContributionSat):
        return facts.feeSat > maxFeeContributionSat
            ? Err(SigningFailure(
                'liquid fee ${facts.feeSat} exceeds cap $maxFeeContributionSat'))
            : const Ok(null);
    }
  }

  // ── Boltz swap creation (commitment check AFTER creation) ─────────────────

  /// Per-type amount rule for a created swap. Pass `exactSat` (reverse/chain
  /// send) OR a `[minSat, maxSat]` range (submarine lockup) — whichever applies.
  /// The Boltz-quoted amount MUST match what the user intended, or a malicious/
  /// buggy server could under-pay a reverse or over-charge a submarine lockup.
  static Result<void, SecretsFailure> checkSwapAmount({
    required int outAmountSat,
    int? exactSat,
    int? minSat,
    int? maxSat,
  }) {
    if (outAmountSat < 0 || outAmountSat > _maxMoneySat) {
      return Err(SigningFailure('swap amount $outAmountSat out of range'));
    }
    if (exactSat != null && outAmountSat != exactSat) {
      return Err(SigningFailure(
          'swap amount $outAmountSat mismatch vs expected $exactSat'));
    }
    if (minSat != null && outAmountSat < minSat) {
      return Err(SigningFailure('swap amount $outAmountSat below floor $minSat'));
    }
    if (maxSat != null && outAmountSat > maxSat) {
      return Err(
          SigningFailure('swap amount $outAmountSat above ceiling $maxSat'));
    }
    return const Ok(null);
  }

  /// Single-leg (reverse/submarine) commitment. All expected values are read
  /// from the SDK-returned swap by the adapter — the caller supplies NO pubkey
  /// or preimage. [weAreReceiver] = reverse (we claim, our key is the receiver);
  /// false = submarine (we refund, our key is the sender).
  ///
  /// Proves the returned redeem script commits to OUR derived [ownPubkey] and
  /// that its hashlock matches OUR preimage's sha256 — so the untrusted
  /// Boltz-supplied address cannot redirect our claim/refund to another key.
  static Result<void, SecretsFailure> validateSwapCommitment({
    required bool weAreReceiver,
    required String ownPubkey,
    required String preimageSha256,
    required String scriptReceiverPubkey,
    required String scriptSenderPubkey,
    required String scriptHashlock,
    required int outAmountSat,
    int? exactSat,
    int? minSat,
    int? maxSat,
  }) {
    final amount = checkSwapAmount(
        outAmountSat: outAmountSat,
        exactSat: exactSat,
        minSat: minSat,
        maxSat: maxSat);
    if (amount is Err<void, SecretsFailure>) return amount;

    final ourScriptKey =
        weAreReceiver ? scriptReceiverPubkey : scriptSenderPubkey;
    if (ourScriptKey != ownPubkey) {
      return const Err(
          SigningFailure('swap script does not commit to own key'));
    }
    if (scriptHashlock != preimageSha256) {
      return const Err(
          SigningFailure('swap hashlock does not match own preimage'));
    }
    return const Ok(null);
  }

  /// Chain-swap commitment: a chain swap commits to BOTH our keys across TWO
  /// scripts (one per chain). The LOCKUP script (where OUR funds go) must commit
  /// to our REFUND key as sender; the CLAIM script must commit to our CLAIM key
  /// as receiver. Which chain is lockup vs claim depends on [direction]:
  /// `btcToLbtc` → BTC lockup / LBTC claim; `lbtcToBtc` → reversed. Both legs'
  /// hashlocks must match OUR preimage. `outAmount` is the send/lockup amount →
  /// exact `sendAmountSat`. Pure so the (bug-prone) leg routing is unit-tested
  /// without the Boltz SDK.
  static Result<void, SecretsFailure> validateChainSwapCommitment({
    required ChainDirection direction,
    required String ownClaimPubkey,
    required String ownRefundPubkey,
    required String preimageSha256,
    required SwapScriptLeg btcScript,
    required SwapScriptLeg lbtcScript,
    required int outAmountSat,
    required int sendAmountSat,
  }) {
    final amount =
        checkSwapAmount(outAmountSat: outAmountSat, exactSat: sendAmountSat);
    if (amount is Err<void, SecretsFailure>) return amount;

    final (lockup, claim) = direction == ChainDirection.btcToLbtc
        ? (btcScript, lbtcScript)
        : (lbtcScript, btcScript);

    // The LOCKUP leg holds OUR funds: it must commit to our refund key (sender).
    if (lockup.senderPubkey != ownRefundPubkey) {
      return const Err(
          SigningFailure('chain lockup script does not commit to own refund key'));
    }
    if (lockup.hashlock != preimageSha256) {
      return const Err(
          SigningFailure('chain lockup hashlock does not match own preimage'));
    }
    // The CLAIM leg pays US: it must commit to our claim key (receiver).
    if (claim.receiverPubkey != ownClaimPubkey) {
      return const Err(
          SigningFailure('chain claim script does not commit to own claim key'));
    }
    if (claim.hashlock != preimageSha256) {
      return const Err(
          SigningFailure('chain claim hashlock does not match own preimage'));
    }
    return const Ok(null);
  }
}
