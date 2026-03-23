import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/data/datasources/dlc_wallet_token_store.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Result of a successful wallet registration.
class DlcWalletRegistrationResult {
  const DlcWalletRegistrationResult({
    required this.walletId,
    required this.walletToken,
    required this.xpub,
    required this.fundingPubkeyHex,
  });

  final String walletId;
  final String walletToken;
  final String xpub;
  final String fundingPubkeyHex;
}

/// Registers the default Bitcoin wallet with the DLC coordinator API and
/// stores the resulting [walletToken] in [DlcWalletTokenStore].
///
/// Registration flow:
///   1. Load default wallet (to get xpub and wallet ID).
///   2. Load seed (to derive master private key for signing).
///   3. Fetch current UTXOs to include in the registration payload.
///   4. Call `POST /auth/nonce` to obtain a challenge nonce.
///   5. Sign `sha256(nonce.encode('utf-8').hex().encode('utf-8'))` with the
///      BIP32 master private key using secp256k1 ECDSA (DER-encoded).
///   6. Call `POST /auth/wallet` with xpub, signature, nonce, and utxos.
///   7. Persist the returned `wallet_token` in [DlcWalletTokenStore].
class RegisterDlcWalletUsecase {
  RegisterDlcWalletUsecase({
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
    required WalletUtxoRepository utxoRepository,
    required DlcApiDatasource dlcApiDatasource,
    required DlcWalletTokenStore tokenStore,
  })  : _walletRepository = walletRepository,
        _seedRepository = seedRepository,
        _utxoRepository = utxoRepository,
        _dlcApiDatasource = dlcApiDatasource,
        _tokenStore = tokenStore;

  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final WalletUtxoRepository _utxoRepository;
  final DlcApiDatasource _dlcApiDatasource;
  final DlcWalletTokenStore _tokenStore;

  Future<DlcWalletRegistrationResult> execute() async {
    // 1. Get the default Bitcoin wallet
    final wallets = await _walletRepository.getWallets(
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) throw Exception('No default Bitcoin wallet found');
    final wallet = wallets.first;
    final xpub = wallet.xpub;

    // 2. Get seed bytes for signing
    final seed = await _seedRepository.get(wallet.masterFingerprint);
    final seedBytes = seed.bytes;

    // 3. Fetch wallet UTXOs (best-effort — registration proceeds even if empty)
    final utxos = await _fetchUtxos(wallet.id);

    // 4. Fetch a one-time nonce from the coordinator
    final nonceResponse = await _dlcApiDatasource.fetchNonce();
    final nonce = nonceResponse['nonce'] as String;

    // 5. Derive master key and sign the nonce
    final root = bip32.Bip32Keys.fromSeed(seedBytes);
    final privateKeyBytes = root.private!;
    final fundingPubkeyHex = hex.encode(root.public);

    final signatureHex = _signNonce(privateKeyBytes, nonce);

    // 6. Register with coordinator
    final regResponse = await _dlcApiDatasource.registerWallet(
      xpub: xpub,
      xpubSignatureHex: signatureHex,
      nonce: nonce,
      label: _walletLabel(wallet),
      utxos: utxos,
    );

    final walletToken = regResponse['wallet_token'] as String? ??
        regResponse['token'] as String?;
    final walletId = regResponse['wallet_id'] as String? ?? '';

    if (walletToken == null) {
      throw Exception(
        'Registration failed: no wallet_token in response. Response: $regResponse',
      );
    }

    // 7. Store the token for use by DlcApiDatasource
    _tokenStore.setRegistration(
      walletToken: walletToken,
      fundingPubkeyHex: fundingPubkeyHex,
      walletId: walletId,
    );

    return DlcWalletRegistrationResult(
      walletId: walletId,
      walletToken: walletToken,
      xpub: xpub,
      fundingPubkeyHex: fundingPubkeyHex,
    );
  }

  String _walletLabel(Wallet wallet) =>
      wallet.label ?? 'BullBitcoin-${wallet.xpubFingerprint}';

  /// Fetches the wallet's current UTXOs and converts them to the format
  /// expected by the DLC coordinator registration endpoint:
  ///   { "txid": "...", "vout": 0, "amount_sat": 100000 }
  ///
  /// Errors are swallowed so registration always proceeds even if the UTXO
  /// fetch fails (e.g. wallet not yet synced).
  Future<List<Map<String, dynamic>>> _fetchUtxos(String walletId) async {
    try {
      final utxos = await _utxoRepository.getWalletUtxos(walletId: walletId);
      return utxos
          .whereType<BitcoinWalletUtxo>()
          .map(
            (u) => <String, dynamic>{
              'txid': u.txId,
              'vout': u.vout,
              'amount_sat': u.amountSat.toInt(),
            },
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Signs the nonce as required by the DLC coordinator:
  ///   message_hex = nonce.encode('utf-8').hex()   // nonce bytes as hex string
  ///   msg_hash    = sha256(message_hex.encode())   // SHA256 of that hex string
  ///   signature   = secp256k1_ecdsa_sign(msg_hash, master_privkey)  // DER hex
  static String _signNonce(Uint8List privateKeyBytes, String nonce) {
    // Replicate Python: message_hex = nonce.encode('utf-8').hex()
    final nonceUtf8 = utf8.encode(nonce);
    final messageHex = hex.encode(nonceUtf8); // hex string of nonce UTF-8 bytes

    // Hash the message_hex string
    final msgHashBytes = sha256
        .convert(utf8.encode(messageHex))
        .bytes;

    // Sign with secp256k1 ECDSA (RFC6979 deterministic)
    final params = ECDomainParameters('secp256k1');
    final privKeyBigInt = _bytesToBigInt(privateKeyBytes);
    final ecPrivKey = ECPrivateKey(privKeyBigInt, params);

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 32));
    final secureRandom = _buildSecureRandom(privateKeyBytes, msgHashBytes);
    signer.init(
      true,
      ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(ecPrivKey),
        secureRandom,
      ),
    );

    final sig = signer.generateSignature(
      Uint8List.fromList(msgHashBytes),
    ) as ECSignature;

    return hex.encode(_derEncodeSignature(sig));
  }

  static BigInt _bytesToBigInt(Uint8List bytes) =>
      BigInt.parse(hex.encode(bytes), radix: 16);

  /// Encode an [ECSignature] in DER format (as used by Bitcoin).
  static Uint8List _derEncodeSignature(ECSignature sig) {
    final rBytes = _bigIntToMinimalBytes(sig.r);
    final sBytes = _bigIntToMinimalBytes(sig.s);

    final rEncoded = _derInteger(rBytes);
    final sEncoded = _derInteger(sBytes);

    final sequence = <int>[
      0x30, // SEQUENCE
      rEncoded.length + sEncoded.length,
      ...rEncoded,
      ...sEncoded,
    ];
    return Uint8List.fromList(sequence);
  }

  static List<int> _derInteger(Uint8List bytes) {
    return [
      0x02, // INTEGER
      bytes.length,
      ...bytes,
    ];
  }

  /// Convert a [BigInt] to the minimal unsigned big-endian byte representation
  /// with a leading 0x00 if the high bit is set (DER positive integer).
  static Uint8List _bigIntToMinimalBytes(BigInt value) {
    final byteCount = (value.bitLength + 7) >> 3;
    final result = <int>[];
    var v = value;
    for (var i = 0; i < byteCount; i++) {
      result.insert(0, (v & BigInt.from(0xff)).toInt());
      v >>= 8;
    }
    // Prepend 0x00 if high bit is set to mark as positive integer
    if (result.isNotEmpty && result.first >= 0x80) {
      result.insert(0, 0x00);
    }
    return Uint8List.fromList(result);
  }

  /// Build a deterministic SecureRandom seeded from private key + message hash.
  /// FortunaRandom requires exactly 32 bytes, so we SHA256 the combined material.
  static SecureRandom _buildSecureRandom(
    Uint8List privKey,
    List<int> msgHash,
  ) {
    final combined = Uint8List.fromList([...privKey, ...msgHash]);
    final seed32 = Uint8List.fromList(sha256.convert(combined).bytes);
    final random = FortunaRandom();
    random.seed(KeyParameter(seed32));
    return random;
  }
}
