import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/signing_intent.dart';

/// The facts a signer extracts from the decoded PSBT/PSET (via BDK/LWK) and
/// feeds to the validator. Separating extraction (native) from the DECISION
/// (pure) is what makes the security gate unit-testable.
class TxFacts {
  const TxFacts({
    required this.outputs,
    required this.feeSat,
    this.version,
    this.lockTime,
    this.inputOutpoints = const [],
    this.inputScriptPubKeys = const [],
    this.lockupScriptAddress,
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

  /// For swaps: the lockup output address actually present in the tx.
  final String? lockupScriptAddress;
}

/// One swap redeem-script's relevant pubkeys + hashlock + locktime (a BTC or
/// LBTC leg).
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

  /// The CLTV timeout block in the redeem script. The refund branch (our funds)
  /// is reachable only at/after this height — it MUST match what the user
  /// intended, or the server could push our refund window out arbitrarily.
  final int locktime;
}

/// Pure validation of a [SigningIntent] against extracted [TxFacts]. A signer
/// MUST call this and refuse to sign on `Err` — BDK/LWK sign blindly (#1703).
class IntentValidator {
  /// [ownsScript] decides whether a scriptPubKey belongs to the signing wallet
  /// (so change is provably owned). The signer supplies it from the wallet
  /// descriptor.
  static Result<void, SecretsFailure> validate(
    SigningIntent intent,
    TxFacts facts, {
    required bool Function(String scriptPubKey) ownsScript,
    String Function(SwapIntent intent)? reconstructLockupAddress,
  }) {
    return switch (intent) {
      SendIntent() => _validateSend(intent, facts, ownsScript),
      PayjoinIntent() => _validatePayjoin(intent, facts),
      SwapIntent() => _validateSwap(intent, facts, reconstructLockupAddress),
    };
  }

  static Result<void, SecretsFailure> _validateSend(
    SendIntent intent,
    TxFacts facts,
    bool Function(String) ownsScript,
  ) {
    if (facts.feeSat > intent.maxFeeSat) {
      return Err(SigningFailure(
          'fee ${facts.feeSat} exceeds cap ${intent.maxFeeSat}'));
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
  /// format the [PayjoinIntent] uses. The original-output check is presence-only
  /// (the receiver legitimately adds/reorders outputs in BIP78); the value bound
  /// is the fee-contribution cap. Finalize both before wiring payjoin.
  static Result<void, SecretsFailure> _validatePayjoin(
    PayjoinIntent intent,
    TxFacts facts,
  ) {
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
    // Every original output the sender declared must still be present.
    final present =
        facts.outputs.map((o) => '${o.scriptPubKey}:${o.amountSat}').toSet();
    for (final o in intent.originalOutputs) {
      if (!present.contains('${o.scriptPubKey}:${o.amountSat}')) {
        return const Err(SigningFailure('payjoin altered an original output'));
      }
    }
    if (facts.feeSat > intent.maxFeeContributionSat) {
      return Err(SigningFailure(
          'payjoin fee contribution ${facts.feeSat} exceeds '
          '${intent.maxFeeContributionSat}'));
    }
    return const Ok(null);
  }

  /// The Boltz-returned swap-script facts the swap signer checks AFTER creation.
  /// The Boltz address is untrusted: we prove the lockup script commits to OUR
  /// derived key and the intent's preimage hash before returning the swap.
  ///
  /// [ownPubkey] = the public key Boltz derived from OUR mnemonic+index
  /// (`swap.keys.publicKey`); [scriptReceiverPubkey]/[scriptSenderPubkey]/
  /// [scriptHashlock] come from the returned `swapScript`.
  /// Pass the OWN key(s) Boltz derived from our mnemonic for the side(s) we
  /// control — claim (reverse), refund (submarine), or BOTH (chain). Each
  /// provided key must match the corresponding returned-script pubkey AND the
  /// intent's pubkey, and the hashlock must match the intent's preimage hash.
  static Result<void, SecretsFailure> validateSwapCommitment(
    SwapIntent intent, {
    String? ownClaimPubkey,
    String? ownRefundPubkey,
    required String scriptReceiverPubkey,
    required String scriptSenderPubkey,
    required String scriptHashlock,
    int scriptLocktime = 0,
    int? expectedLocktime,
  }) {
    if (ownClaimPubkey == null && ownRefundPubkey == null) {
      return const Err(
          SigningFailure('swap commitment: no own key supplied to verify'));
    }
    if (ownClaimPubkey != null) {
      if (scriptReceiverPubkey != ownClaimPubkey) {
        return const Err(
            SigningFailure('swap claim script does not commit to own key'));
      }
      if (intent.claimPubkey != ownClaimPubkey) {
        return const Err(
            SigningFailure('swap claim pubkey mismatch vs intent'));
      }
    }
    if (ownRefundPubkey != null) {
      if (scriptSenderPubkey != ownRefundPubkey) {
        return const Err(
            SigningFailure('swap refund script does not commit to own key'));
      }
      if (intent.refundPubkey != ownRefundPubkey) {
        return const Err(
            SigningFailure('swap refund pubkey mismatch vs intent'));
      }
    }
    if (scriptHashlock != intent.preimageHash) {
      return const Err(SigningFailure('swap hashlock mismatch vs intent'));
    }
    // Bind the redeem-script locktime to the user's intended timeout. Opt-in:
    // only enforced when the caller supplies a positive [expectedLocktime]
    // (the Boltz-quoted timeout it asked for), so a caller that can't know the
    // server value ahead of time is not blocked — but when it can, the server
    // can no longer push our refund window out.
    if (expectedLocktime != null &&
        expectedLocktime > 0 &&
        scriptLocktime != expectedLocktime) {
      return Err(SigningFailure(
          'swap locktime $scriptLocktime mismatch vs intent $expectedLocktime'));
    }
    return const Ok(null);
  }

  /// Chain-swap commitment: a chain swap commits to BOTH our keys across TWO
  /// scripts (one per chain). The LOCKUP script (where our funds go) must commit
  /// to our REFUND key as sender; the CLAIM script must commit to our CLAIM key
  /// as receiver. Which chain is lockup vs claim depends on [direction]:
  /// `btcToLbtc` → BTC lockup / LBTC claim; `lbtcToBtc` → reversed. Pure so the
  /// (bug-prone) leg routing is unit-tested without the Boltz SDK.
  static Result<void, SecretsFailure> validateChainSwapCommitment(
    SwapIntent intent, {
    required ChainDirection direction,
    required String ownClaimPubkey,
    required String ownRefundPubkey,
    required SwapScriptLeg btcScript,
    required SwapScriptLeg lbtcScript,
  }) {
    final (lockup, claim) = direction == ChainDirection.btcToLbtc
        ? (btcScript, lbtcScript)
        : (lbtcScript, btcScript);
    final refundLeg = validateSwapCommitment(
      intent,
      ownRefundPubkey: ownRefundPubkey,
      scriptReceiverPubkey: lockup.receiverPubkey,
      scriptSenderPubkey: lockup.senderPubkey,
      scriptHashlock: lockup.hashlock,
      // The LOCKUP leg holds OUR funds: bind its refund locktime to the intent.
      scriptLocktime: lockup.locktime,
      expectedLocktime: intent.timeout,
    );
    if (refundLeg is Err<void, SecretsFailure>) return refundLeg;
    return validateSwapCommitment(
      intent,
      ownClaimPubkey: ownClaimPubkey,
      scriptReceiverPubkey: claim.receiverPubkey,
      scriptSenderPubkey: claim.senderPubkey,
      scriptHashlock: claim.hashlock,
      // The CLAIM leg's locktime protects Boltz, not our funds (and differs per
      // chain), so it is not bound to the single intent timeout.
      scriptLocktime: claim.locktime,
    );
  }

  static Result<void, SecretsFailure> _validateSwap(
    SwapIntent intent,
    TxFacts facts,
    String Function(SwapIntent)? reconstructLockupAddress,
  ) {
    if (reconstructLockupAddress == null) {
      return const Err(
          SigningFailure('swap validation requires a reconstruction fn'));
    }
    final expected = reconstructLockupAddress(intent);
    final actual = facts.lockupScriptAddress;
    if (actual == null) {
      return const Err(SigningFailure('swap tx has no lockup output'));
    }
    if (expected != actual) {
      // The Boltz-supplied address does NOT commit to our own derived key —
      // refuse (never trust the server's address).
      return const Err(
          SigningFailure('swap lockup address does not match own key'));
    }
    return const Ok(null);
  }
}
