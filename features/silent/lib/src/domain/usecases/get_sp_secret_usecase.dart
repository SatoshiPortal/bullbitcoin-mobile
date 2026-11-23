import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

typedef ReadSilentFingerprint = Future<Result<Fingerprint?, Failure>> Function(
  BitcoinNetwork network,
);

/// The secret a Silent Payments account is opened from: the one behind the
/// default Bitcoin wallet of the account's own network.
///
/// A handle, never the words: `Secret.silentPaymentsAccount` hands the BIP39 seed to bwk
/// inside the package. Every failure carries fixed text, since this is the
/// seed path.
class GetSpSecretUsecase {
  final ReadSilentFingerprint _readDefaultFingerprint;
  final Secrets _secrets;

  GetSpSecretUsecase({
    required this._readDefaultFingerprint,
    required this._secrets,
  });

  @useResult
  Future<Result<Secret, SilentFailure>> execute(BitcoinNetwork network) async {
    if (!NetworkCapabilities.supports(
      network,
      NetworkCapability.silentPayments,
    )) {
      return const Err(SilentUnsupportedNetwork());
    }
    // Mainnet and testnet defaults need not share a seed: the account must be
    // the one of the network it scans.
    final id = (await _readDefaultFingerprint(network))
        .fold((value) => value, (_) => null);
    if (id == null) {
      return const Err(SilentUnexpected('SP secret lookup failed'));
    }

    switch (await _secrets.fetch(id)) {
      case Ok(:final value):
        return Ok(value);
      case Err():
        return const Err(SilentUnexpected('SP secret lookup failed'));
    }
  }
}
