import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';
import 'package:bb_mobile/features/pos/domain/value_objects/pos_network.dart';
import 'package:boltz/boltz.dart' as boltz;
import 'package:crypto/crypto.dart';
import 'package:nostr_pos/nostr_pos.dart' as nostr;
import 'package:pointycastle/digests/ripemd160.dart';

class PosRecoveryClaimBuilder {
  const PosRecoveryClaimBuilder({required PosNetwork network})
    : _network = network;

  final PosNetwork _network;

  Future<String> call(nostr.RecoveryClaimBuildRequest request) async {
    try {
      final swap = request.material.swap;
      if (swap == null) {
        throw const FormatException('Recovery material missing swap object.');
      }
      final response = _map(swap['boltzResponse']);
      final preimageHex = _string(swap, 'preimage');
      final preimageHash = _string(swap, 'preimageHash');
      final claimPrivateKey = _string(swap, 'claimPrivateKey');
      final claimPublicKey = _string(
        swap,
        'claimPublicKey',
        fallback: response['claimPublicKey'],
      );
      final refundPublicKey = _string(response, 'refundPublicKey');
      final blindingKey = _string(response, 'blindingKey');
      final invoice = _string(swap, 'invoice');
      final outAddress =
          request.material.settlementAddress ?? _string(swap, 'claimAddress');
      final outAmount = _int(swap, 'expectedAmountSat');
      final timeoutBlockHeight = _int(swap, 'timeoutBlockHeight');

      final preimage = await boltz.PreImage.newInstance(
        value: preimageHex,
        sha256: preimageHash,
        hash160: _hash160Hex(preimageHex),
      );
      final keys = await boltz.KeyPair.newInstance(
        secretKey: claimPrivateKey,
        publicKey: claimPublicKey,
      );
      final swapScript = await boltz.LBtcSwapScriptStr.newInstance(
        swapType: boltz.SwapType.reverse,
        hashlock: preimageHash,
        receiverPubkey: claimPublicKey,
        locktime: timeoutBlockHeight,
        senderPubkey: refundPublicKey,
        blindingKey: blindingKey,
      );
      final hydrated = await boltz.LbtcLnSwap.newInstance(
        id: request.recovery.swapId,
        kind: boltz.SwapType.reverse,
        network: _network.isTestnet
            ? boltz.Chain.liquidTestnet
            : boltz.Chain.liquid,
        keys: keys,
        keyIndex: BigInt.zero,
        preimage: preimage,
        swapScript: swapScript,
        invoice: invoice,
        outAmount: BigInt.from(outAmount),
        outAddress: outAddress,
        blindingKey: blindingKey,
        electrumUrl: _electrumUrl,
        boltzUrl: _boltzUrl,
        referralId: ApiServiceConstants.boltzReferralId,
      );
      return hydrated.claim(
        outAddress: outAddress,
        minerFee: request.feeSatPerVbyte == null
            ? boltz.TxFee.relative(0.1)
            : boltz.TxFee.relative(request.feeSatPerVbyte!),
        tryCooperate: true,
      );
    } catch (error) {
      throw PosRecoveryClaimFailure(
        swapId: request.recovery.swapId,
        reason: '$error',
      );
    }
  }

  String get _electrumUrl {
    return _network.isTestnet
        ? ApiServiceConstants.bbLiquidElectrumTestUrlPath
        : ApiServiceConstants.bbLiquidElectrumUrlPath;
  }

  String get _boltzUrl {
    final base = _network.sdkNetwork.boltzApiBase.replaceAll(
      RegExp(r'/+$'),
      '',
    );
    return base.endsWith('/v2') ? base : '$base/v2';
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    if (value is String && value.isNotEmpty) {
      return (jsonDecode(value) as Map).cast<String, Object?>();
    }
    return const {};
  }

  String _string(Map<String, Object?> map, String key, {Object? fallback}) {
    final value = map[key] ?? fallback;
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('Recovery material missing $key.');
  }

  int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw FormatException('Recovery material missing $key.');
  }

  String _hash160Hex(String preimageHex) {
    final bytes = _hexBytes(preimageHex);
    final sha = Uint8List.fromList(sha256.convert(bytes).bytes);
    final ripe = RIPEMD160Digest().process(sha);
    return ripe.toHexString();
  }

  Uint8List _hexBytes(String hex) {
    final lower = hex.toLowerCase();
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(lower) || lower.length.isOdd) {
      throw const FormatException('Invalid hex value.');
    }
    return Uint8List.fromList([
      for (var i = 0; i < lower.length; i += 2)
        int.parse(lower.substring(i, i + 2), radix: 16),
    ]);
  }
}
