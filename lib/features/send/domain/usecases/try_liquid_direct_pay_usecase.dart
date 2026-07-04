import 'package:bb_mobile/features/send/domain/errors/bullpay_proof_error.dart';
import 'package:bb_mobile/features/send/domain/ports/liquid_direct_pay_port.dart';
import 'package:bb_mobile/features/send/domain/usecases/build_bullpay_proof_usecase.dart';

// LUD-16 username: lowercase alnum + `._-`, max 64. Rejects path traversal,
// scheme bleed, whitespace, etc.
final _usernameRegex = RegExp(r'^[a-z0-9._-]{1,64}$');
// Strict hostname: dot-separated lowercase labels, max 253 chars, no `..`,
// no `/`, no `:` (port not allowed in metadata host). The TLD must start with a
// letter — this rejects IP literals (127.0.0.1) and bare hostnames; only
// DNS-resolved domains pass.
final _domainRegex = RegExp(
  r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]([a-z0-9-]{0,61}[a-z0-9])?$',
);

/// Attempts a LUD-22 Liquid direct-pay to a Bull Lightning address and returns
/// the L-BTC address to pay directly. Every "direct pay not possible" outcome
/// (bad address, unavailable metadata, no `L-BTC` method, SSRF-pin failure, a
/// Lightning soft-limit fallback, or a malformed response) is a quiet
/// [LiquidDirectPayUnavailable]; the send-cubit then routes the normal
/// Lightning swap and shows nothing extra (DG-8). A hard server rejection is a
/// [BullpayProofError] — also a fallback trigger, but logged.
///
/// DG-7: the value floor is enforced server-side by unblinding the proof.
/// DG-8: a returned bolt11 invoice is declined (never paid blindly) so the swap
/// fee is priced and shown through the normal send path.
class TryLiquidDirectPayUsecase {
  final BuildBullpayProofUsecase _buildProof;
  final LiquidDirectPayPort _liquidDirectPay;

  TryLiquidDirectPayUsecase({
    required this._buildProof,
    required this._liquidDirectPay,
  });

  Future<String> execute({
    required String lnAddress,
    required int amountSat,
    required String walletId,
  }) async {
    final parts = lnAddress.split('@');
    if (parts.length != 2) {
      throw const LiquidDirectPayUnavailable();
    }

    final username = parts[0].toLowerCase();
    final domain = parts[1].toLowerCase();
    if (!_usernameRegex.hasMatch(username) ||
        domain.length > 253 ||
        !_domainRegex.hasMatch(domain)) {
      throw const LiquidDirectPayUnavailable();
    }

    final metadataUrl = Uri.https(domain, '/.well-known/lnurlp/$username');

    final metadata = await _liquidDirectPay.fetchMetadata(metadataUrl);

    final hasLiquid = metadata.paymentMethods.contains('L-BTC');
    if (!hasLiquid) {
      throw const LiquidDirectPayUnavailable();
    }

    final callback = metadata.callback;
    // Pin to https + the same domain we just validated. Defeats a malicious
    // LNURLP responder redirecting the proof-of-funds callback to attacker
    // hosts. Must fire BEFORE the proof is sent.
    if (callback.scheme != 'https' || callback.host != domain) {
      throw const LiquidDirectPayUnavailable();
    }

    final proof = await _buildProof.execute(walletId: walletId, nym: username);

    final msats = amountSat * 1000;
    // Approach-B payload: the ownership proof plus the output's opening
    // (value + factors + asset id) straight from TxOutSecrets. No blinding key.
    final query = {
      'amount': msats.toString(),
      'payment_method': 'L-BTC',
      'outpoint': proof.outpoint,
      'pubkey': proof.pubkeyHex,
      'sig': proof.sigDerHex,
      'value': proof.valueSat.toString(),
      'value_bf': proof.valueBfHex,
      'asset': proof.assetIdHex,
      'asset_bf': proof.assetBfHex,
    };

    final data = await _liquidDirectPay.requestLiquidPayment(
      callback,
      query: query,
    );

    if (data.status == 'ERROR') {
      final code = data.code;
      if (code != null) {
        throw BullpayProofError.fromServerCode(
          code: code,
          reason: data.reason,
          minSat: data.minSat,
        );
      }
      throw BullpayProofInternal('UnknownServerError');
    }

    // Soft rate-limit: the server answered with a Lightning invoice instead of
    // an L-BTC address. Decline it and fall back to the normal swap (DG-8) —
    // never pay a server-supplied bolt11 blindly.
    if (data.bolt11 != null) {
      throw const LiquidDirectPayUnavailable();
    }

    final address = data.liquidAddress;
    if (address == null) {
      // No clear success and no error code — treat as unavailable and fall back
      // gracefully (also covers a server without the LUD-22 handler, DG-9).
      throw const LiquidDirectPayUnavailable();
    }
    return address;
  }
}
