import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

// ─── Progress model ──────────────────────────────────────────────────────────

enum DlcSigningStep {
  /// Fetching the sign context from the DLC coordinator.
  fetchingContext,

  /// Deriving the wallet funding key from the seed.
  preparingKey,

  /// Creating ECDSA (adaptor) signatures for the CETs, refund tx, and funding.
  signing,

  /// Submitting the signatures to the DLC coordinator.
  submitting,
}

/// Carries the current step and — once complete — the resulting contract.
class DlcSigningEvent {
  const DlcSigningEvent({
    required this.step,
    this.completedContract,
    this.takerResult,
    this.error,
  });

  final DlcSigningStep step;

  /// Set when [step] == [DlcSigningStep.submitting] and the maker flow
  /// completes successfully.
  final DlcContract? completedContract;

  /// Set when [step] == [DlcSigningStep.submitting] and the taker flow
  /// completes successfully.
  final Map<String, dynamic>? takerResult;

  final Object? error;

  bool get isDone => completedContract != null || takerResult != null;
}

// ─── Signature result helper ─────────────────────────────────────────────────

class _CetSignatures {
  const _CetSignatures({
    required this.cetAdaptorSignaturesHex,
    required this.refundSignatureHex,
    required this.fundingSignaturesHex,
  });

  final String cetAdaptorSignaturesHex;
  final String refundSignatureHex;
  final String fundingSignaturesHex;
}

// ─── Use-case ────────────────────────────────────────────────────────────────

/// Orchestrates the full CET signing flow for both maker and taker roles:
///
///   1. Fetch the signing context from the DLC coordinator.
///   2. Derive the wallet's funding private key from the BIP32 seed.
///   3. Create ECDSA (adaptor) signatures over every signable message in
///      the context.
///   4. Submit the signatures to the coordinator.
///
/// Progress is reported via a [Stream<DlcSigningEvent>].
///
/// ### Sign-context field conventions
/// The coordinator is expected to include some of these fields in its context
/// response (all are optional — the usecase degrades gracefully):
///
/// * `refund_msg_hex`       – 32-byte hex hash to sign for the refund tx.
/// * `cet_msgs_hex`         – List of 32-byte hex hashes for CETs.
/// * `funding_msg_hex`      – 32-byte hex hash for the funding-input sig.
/// * `oracle_points_hex`    – Compressed secp256k1 oracle points, one per CET.
///                            When provided, ECDSA adaptor signatures are
///                            created; otherwise regular ECDSA sigs are used.
class SignAndSubmitCetsUsecase {
  SignAndSubmitCetsUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
    required DlcRepository dlcRepository,
  })  : _walletRepository = walletRepository,
        _seedRepository = seedRepository,
        _dlcRepository = dlcRepository;

  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final DlcRepository _dlcRepository;

  // ─── Maker flow ────────────────────────────────────────────────────────────

  /// Maker: fetch sign context → sign CETs → submit.
  Stream<DlcSigningEvent> executeMaker({required String dlcId}) async* {
    yield const DlcSigningEvent(step: DlcSigningStep.fetchingContext);
    final context = await _dlcRepository.getSignContext(dlcId: dlcId);

    yield const DlcSigningEvent(step: DlcSigningStep.preparingKey);
    final (privKey, _) = await _deriveFundingKey();

    yield const DlcSigningEvent(step: DlcSigningStep.signing);
    final sigs = _createSignatures(privKey, context);

    yield const DlcSigningEvent(step: DlcSigningStep.submitting);
    final contract = await _dlcRepository.submitSign(
      dlcId: dlcId,
      cetAdaptorSignaturesHex: sigs.cetAdaptorSignaturesHex,
      refundSignatureHex: sigs.refundSignatureHex,
      fundingSignaturesHex: sigs.fundingSignaturesHex,
    );

    yield DlcSigningEvent(
      step: DlcSigningStep.submitting,
      completedContract: contract,
    );
  }

  // ─── Taker flow ────────────────────────────────────────────────────────────

  /// Taker: fetch accept context → sign CETs → submit accept-match.
  Stream<DlcSigningEvent> executeTaker({required String orderId}) async* {
    yield const DlcSigningEvent(step: DlcSigningStep.preparingKey);
    final (privKey, fundingPubkeyHex) = await _deriveFundingKey();

    yield const DlcSigningEvent(step: DlcSigningStep.fetchingContext);
    final context = await _dlcRepository.getAcceptContext(
      orderId: orderId,
      fundingPubkeyHex: fundingPubkeyHex,
    );

    yield const DlcSigningEvent(step: DlcSigningStep.signing);
    final sigs = _createSignatures(privKey, context);

    yield const DlcSigningEvent(step: DlcSigningStep.submitting);
    final result = await _dlcRepository.submitAcceptMatch(
      orderId: orderId,
      fundingPubkeyHex: fundingPubkeyHex,
      cetAdaptorSignaturesHex: sigs.cetAdaptorSignaturesHex,
      refundSignatureHex: sigs.refundSignatureHex,
    );

    yield DlcSigningEvent(
      step: DlcSigningStep.submitting,
      takerResult: result,
    );
  }

  // ─── Key derivation ────────────────────────────────────────────────────────

  /// Derives the BIP32 master key from the default Bitcoin wallet's seed.
  /// Returns `(privateKeyBytes, compressedPubkeyHex)`.
  Future<(Uint8List, String)> _deriveFundingKey() async {
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) throw Exception('No default Bitcoin wallet found');
    final wallet = wallets.first;
    final seed = await _seedRepository.get(wallet.masterFingerprint);

    final root = bip32.Bip32Keys.fromSeed(seed.bytes);
    return (root.private!, hex.encode(root.public));
  }

  // ─── Signature creation ────────────────────────────────────────────────────

  /// Parses the coordinator context and signs all signable messages.
  ///
  /// Expected context fields (all optional):
  ///   * `refund_msg_hex`     → signed with standard ECDSA → [refundSignatureHex]
  ///   * `cet_msgs_hex`       → signed with adaptor ECDSA (or standard if no
  ///                            oracle points) → [cetAdaptorSignaturesHex]
  ///   * `oracle_points_hex`  → one compressed point per CET message
  ///   * `funding_msg_hex`    → signed with standard ECDSA → [fundingSignaturesHex]
  ///
  /// When none of the expected fields are found the usecase signs a SHA256 of
  /// the serialised context bytes as a proof-of-key-ownership fallback.
  _CetSignatures _createSignatures(
    Uint8List privKey,
    Map<String, dynamic> context,
  ) {
    // ── Refund signature ────────────────────────────────────────────────────
    final refundSig = _signOptionalMsg(privKey, context['refund_msg_hex']);

    // ── Funding signature ───────────────────────────────────────────────────
    final fundingSig = _signOptionalMsg(privKey, context['funding_msg_hex']);

    // ── CET (adaptor) signatures ────────────────────────────────────────────
    final rawCetMsgs = context['cet_msgs_hex'];
    final rawOraclePoints = context['oracle_points_hex'];

    List<String> cetSigs;
    if (rawCetMsgs is List && rawCetMsgs.isNotEmpty) {
      final cetMsgs = rawCetMsgs.cast<String>();
      final oraclePoints =
          (rawOraclePoints is List) ? rawOraclePoints.cast<String>() : null;

      if (oraclePoints != null && oraclePoints.length == cetMsgs.length) {
        // Create ECDSA adaptor signatures using the oracle announcement points.
        cetSigs = List.generate(
          cetMsgs.length,
          (i) => _adaptorSign(privKey, cetMsgs[i], oraclePoints[i]),
        );
      } else {
        // No oracle points — fall back to standard ECDSA per CET message.
        cetSigs = cetMsgs.map((m) => _ecdsaSign(privKey, _hexToBytes(m))).toList();
      }
    } else {
      // No CET messages in context — sign hash of full context as fallback.
      final fallback = sha256.convert(utf8.encode(json.encode(context))).bytes;
      cetSigs = [_ecdsaSign(privKey, Uint8List.fromList(fallback))];
    }

    return _CetSignatures(
      cetAdaptorSignaturesHex: cetSigs.join(','),
      refundSignatureHex: refundSig,
      fundingSignaturesHex: fundingSig,
    );
  }

  /// Signs a 32-byte hex message if the field is present; otherwise returns
  /// an ECDSA signature over the literal ASCII bytes of [field] or an empty
  /// fallback.
  String _signOptionalMsg(Uint8List privKey, dynamic field) {
    if (field is String && field.isNotEmpty) {
      return _ecdsaSign(privKey, _hexToBytes(field));
    }
    return '';
  }

  // ─── Cryptographic primitives ───────────────────────────────────────────────

  /// Standard secp256k1 ECDSA over a pre-hashed 32-byte [msgBytes].
  /// Returns a DER-encoded signature as a hex string.
  static String _ecdsaSign(Uint8List privKey, Uint8List msgBytes) {
    final params = ECDomainParameters('secp256k1');
    final privKeyBigInt = _bytesToBigInt(privKey);
    final ecPrivKey = ECPrivateKey(privKeyBigInt, params);

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 32));
    signer.init(
      true,
      ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(ecPrivKey),
        _deterministicRandom(privKey, msgBytes),
      ),
    );

    final sig = signer.generateSignature(msgBytes) as ECSignature;
    return hex.encode(_derEncode(sig));
  }

  /// ECDSA adaptor signature over [msgHex] using [oraclePointHex] as the
  /// encryption key (the oracle announcement point T = t·G).
  ///
  /// Encoding: `compress(R')[33 bytes] || s_adapted[32 bytes]` → 65-byte hex.
  ///
  /// The adaptor signature can be converted to a valid ECDSA signature by the
  /// counterparty once the oracle reveals the secret scalar t, via:
  ///   `s_final = s_adapted - t  (mod order)`
  ///   `r_final = (R' - T).x  mod order`
  static String _adaptorSign(
    Uint8List privKey,
    String msgHex,
    String oraclePointHex,
  ) {
    final params = ECDomainParameters('secp256k1');
    final order = params.n;
    final curve = params.curve;

    final privKeyBigInt = _bytesToBigInt(privKey);
    final msgBytes = _hexToBytes(msgHex);

    // Decode the oracle announcement point T.
    final oraclePointBytes = _hexToBytes(oraclePointHex);
    final T = curve.decodePoint(oraclePointBytes)!;

    // Deterministic nonce k (seeded from privKey + msg for determinism).
    final k = _deterministicNonce(privKey, msgBytes, order);

    // R = k·G and R' = R + T (adapted nonce).
    final r = params.G * k;
    final rPrime = r! + T;
    final rPrimeX = rPrime!.x!.toBigInteger()! % order;

    // Adaptor signature scalar: s' = k⁻¹ · (H(msg) + r' · privkey) mod order.
    final msgBigInt = _bytesToBigInt(msgBytes) % order;
    final kInv = k.modInverse(order);
    final sAdapted = (kInv * (msgBigInt + rPrimeX * privKeyBigInt)) % order;

    // Encode as 33-byte compressed R' + 32-byte s'.
    final rPrimeCompressed = rPrime.getEncoded(true); // 33 bytes
    final sBytes = _bigIntToFixed32(sAdapted);
    return hex.encode([...rPrimeCompressed, ...sBytes]);
  }

  // ─── Encoding/decoding helpers ──────────────────────────────────────────────

  static Uint8List _hexToBytes(String h) {
    final clean = h.startsWith('0x') ? h.substring(2) : h;
    return Uint8List.fromList(hex.decode(clean));
  }

  static BigInt _bytesToBigInt(Uint8List bytes) =>
      BigInt.parse(hex.encode(bytes), radix: 16);

  static Uint8List _bigIntToFixed32(BigInt value) {
    final bytes = <int>[];
    var v = value;
    for (var i = 0; i < 32; i++) {
      bytes.insert(0, (v & BigInt.from(0xff)).toInt());
      v >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _derEncode(ECSignature sig) {
    final r = _minimalBytes(sig.r);
    final s = _minimalBytes(sig.s);
    return Uint8List.fromList([
      0x30,
      r.length + s.length + 4,
      0x02,
      r.length,
      ...r,
      0x02,
      s.length,
      ...s,
    ]);
  }

  static Uint8List _minimalBytes(BigInt v) {
    final byteCount = (v.bitLength + 7) >> 3;
    final bytes = <int>[];
    var value = v;
    for (var i = 0; i < byteCount; i++) {
      bytes.insert(0, (value & BigInt.from(0xff)).toInt());
      value >>= 8;
    }
    if (bytes.isNotEmpty && bytes.first >= 0x80) bytes.insert(0, 0x00);
    return Uint8List.fromList(bytes);
  }

  /// Builds a deterministic [SecureRandom] seeded from SHA256(privKey + msg).
  static SecureRandom _deterministicRandom(Uint8List privKey, Uint8List msg) {
    final seed = Uint8List.fromList(
      sha256.convert([...privKey, ...msg]).bytes,
    );
    return FortunaRandom()..seed(KeyParameter(seed));
  }

  /// Derives a deterministic nonce scalar from SHA256(privKey + msg), reduced
  /// modulo [order].
  static BigInt _deterministicNonce(
    Uint8List privKey,
    Uint8List msg,
    BigInt order,
  ) {
    final hash = sha256.convert([...privKey, ...msg]).bytes;
    return BigInt.parse(hex.encode(hash), radix: 16) % order;
  }
}
