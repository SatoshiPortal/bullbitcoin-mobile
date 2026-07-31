import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/change_address_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// The wallet's own change addresses that have never been used, offered as
/// sweep destinations.
///
/// Why this exists: sweeping to your own empty change address is the common
/// case (re-organising coins without handing them to anyone), and typing a
/// self-owned address by hand is both tedious and a footgun. Only *empty*
/// addresses are offered — reusing an address that already saw a payment links
/// the two on-chain, which is the privacy leak a coin-control screen exists to
/// avoid in the first place.
class GetOwnChangeAddressesUsecase {
  final ChangeAddressPort _addressRepository;

  GetOwnChangeAddressesUsecase({required ChangeAddressPort changeAddressPort})
    : _addressRepository = changeAddressPort;

  /// Unused, zero-balance change addresses for [walletId], newest index first.
  ///
  /// [limit] caps how far back through the revealed change addresses to look.
  @useResult
  Future<Result<List<WalletAddress>, SweepFailure>> execute({
    required String walletId,
    int limit = 20,
  }) async {
    try {
      // Named "used" but it returns the *revealed* change addresses enriched
      // with balance and history — the filter below is what makes them empty.
      final revealed = await _addressRepository.getUsedChangeAddresses(
        walletId,
        limit: limit,
        descending: true,
      );

      final empty = revealed
          .where((address) => !address.isUsed && address.balanceSat == 0)
          .toList();

      return Ok(empty);
    } on Exception catch (e, st) {
      log.warning('Failed to list own change addresses', error: e, trace: st);
      return Err(SweepChangeAddressesUnavailableFailure(e.toString()));
    }
  }
}
