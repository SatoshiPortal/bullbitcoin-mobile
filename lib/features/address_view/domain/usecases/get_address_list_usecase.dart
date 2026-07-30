import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:meta/meta.dart';

class GetAddressListUsecase {
  final WalletAddressRepository _walletAddressRepository;

  const GetAddressListUsecase({required this._walletAddressRepository});

  @useResult
  Future<Result<List<WalletAddress>, AddressViewFailure>> execute({
    required String walletId,
    bool isChange = false,
    int? limit,
    int? fromIndex,
  }) async {
    try {
      final addresses = isChange
          ? await _walletAddressRepository.getUsedChangeAddresses(
              walletId,
              limit: limit,
              fromIndex: fromIndex,
              descending: true,
            )
          : await _walletAddressRepository.getGeneratedReceiveAddresses(
              walletId,
              limit: limit,
              fromIndex: fromIndex,
            );

      return Ok(addresses);
    } on WalletNotFound catch (_, st) {
      log.warning('Wallet metadata missing while listing addresses', trace: st);
      return const Err(AddressViewWalletNotFoundFailure());
    } catch (e, st) {
      log.severe(
        message: 'Failed to list wallet addresses',
        error: e,
        trace: st,
      );
      return Err(
        AddressViewAddressesUnavailableFailure(e.runtimeType.toString()),
      );
    }
  }
}
