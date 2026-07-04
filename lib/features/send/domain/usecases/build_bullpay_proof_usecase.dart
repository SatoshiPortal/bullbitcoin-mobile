import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/entities/bullpay_proof.dart';
import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bitcoin_base/bitcoin_base.dart' show ECPrivate;
import 'package:crypto/crypto.dart';

/// Protocol tag prefixing the ownership digest. This is the recipient server's
/// wire contract — changing it is a breaking protocol change.
const String kBullpayMessageTag = 'bullpay-lnurlp-v1';

/// Local UTXO pre-filter matching the server's `min_proof_value_sat` default
/// (DG-7). The client never trusts its own value claim for security — the
/// server unblinds and enforces — but filtering here avoids a guaranteed-reject
/// round-trip and makes descriptor-index exhaustion cost real coins.
const int kBullpayMinProofValueSat = 1000;

/// Builds the LUD-22 proof-of-funds for a Bull Lightning address, using the
/// Approach-B (factor reconstruction) contract: the proof carries the output's
/// unblinded value plus its value/asset blinding factors and asset id — all
/// read straight from LWK's `TxOutSecrets` — so NO blinding key and NO
/// hand-rolled confidential-transaction crypto ever leave the device. The
/// output's own P2WPKH spending key signs the ownership digest and is zeroized
/// immediately after use (charter §2.7 / H1–H5).
class BuildBullpayProofUsecase {
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;

  BuildBullpayProofUsecase({
    required this._walletRepository,
    required this._seedRepository,
    required this._getWalletUtxosUsecase,
  });

  Future<BullpayProof> execute({
    required String walletId,
    required String nym,
  }) async {
    try {
      return await _build(walletId: walletId, nym: nym);
    } on BullpayProofError {
      rethrow;
    } catch (e, st) {
      log.severe(error: e, trace: st);
      throw BullpayProofInternal('UnexpectedError');
    }
  }

  Future<BullpayProof> _build({
    required String walletId,
    required String nym,
  }) async {
    final wallet = await _walletRepository.getWallet(walletId);
    if (wallet == null || !wallet.isLiquid) {
      throw BullpayProofRequiresProof();
    }

    // Pure-Dart canonical L-BTC asset ids (identical to the SDK's
    // getLbtcAssetId()/getLtestAssetId(), but usable without the Rust bridge so
    // the builder is testable at L0).
    final lbtcAssetId = wallet.isTestnet
        ? AssetConstants.lbtcTestnet
        : AssetConstants.lbtcMainnet;
    final minSat = BigInt.from(kBullpayMinProofValueSat);

    final utxos = await _getWalletUtxosUsecase.execute(walletId: walletId);
    final candidates =
        utxos
            .whereType<LiquidWalletUtxo>()
            .where(
              (u) =>
                  // A user-frozen coin is off-limits to every flow: never
                  // reveal its outpoint + blinding factors to the recipient
                  // server as proof-of-funds (honors the coin-control freeze
                  // contract).
                  !u.isFrozen &&
                  u.assetIdHex == lbtcAssetId &&
                  u.amountSat >= minSat &&
                  u.addressIndex != null,
            )
            .toList()
          ..sort((a, b) => a.amountSat.compareTo(b.amountSat));

    if (candidates.isEmpty) {
      throw BullpayProofRequiresProof();
    }

    final utxo = candidates.first;
    final addressIndex = utxo.addressIndex!;

    final scriptBytes = _hexToBytes(utxo.scriptPubkey);
    if (scriptBytes.length != 22 ||
        scriptBytes[0] != 0x00 ||
        scriptBytes[1] != 0x14) {
      throw BullpayProofPubkeyMismatch();
    }
    final scriptHash = scriptBytes.sublist(2);

    final seed = await _seedRepository.get(wallet.masterFingerprint);
    final root = bip32.Bip32Keys.fromSeed(seed.bytes);
    final extKey = root.derivePath('${wallet.derivationPath}/0/$addressIndex');
    final intKey = root.derivePath('${wallet.derivationPath}/1/$addressIndex');

    final Uint8List signingPriv;
    final Uint8List signingPub;
    if (_bytesEqual(scriptHash, extKey.identifier)) {
      signingPriv = extKey.private!;
      signingPub = extKey.public;
      _zeroize(intKey.private);
    } else if (_bytesEqual(scriptHash, intKey.identifier)) {
      signingPriv = intKey.private!;
      signingPub = intKey.public;
      _zeroize(extKey.private);
    } else {
      _zeroize(extKey.private);
      _zeroize(intKey.private);
      throw BullpayProofPubkeyMismatch();
    }

    final outpoint = '${utxo.txId}:${utxo.vout}';
    final digest = sha256.convert(<int>[
      ...utf8.encode(kBullpayMessageTag),
      ...utf8.encode(nym),
      ...utf8.encode(outpoint),
    ]).bytes;

    final sigDerHex = ECPrivate.fromBytes(
      signingPriv,
    ).signECDSA(digest, sighash: null);
    final pubkeyHex = _bytesToHex(signingPub);

    _zeroize(signingPriv);

    return BullpayProof(
      outpoint: outpoint,
      pubkeyHex: pubkeyHex,
      sigDerHex: sigDerHex,
      valueSat: utxo.amountSat,
      // Elements display-order hex straight from TxOutSecrets — passed verbatim,
      // never re-hexed from raw bytes.
      valueBfHex: utxo.valueBf,
      assetBfHex: utxo.assetBf,
    );
  }
}

void _zeroize(Uint8List? bytes) {
  if (bytes == null) return;
  bytes.fillRange(0, bytes.length, 0);
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(List<int> bytes) {
  final buf = StringBuffer();
  for (final b in bytes) {
    buf.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
