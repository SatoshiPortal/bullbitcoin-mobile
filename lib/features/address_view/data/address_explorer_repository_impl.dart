import 'package:bb_mobile/features/address_view/data/address_electrum_datasource.dart';
import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/address_explorer_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

class AddressExplorerRepositoryImpl implements AddressExplorerRepository {
  final AddressElectrumDatasource _datasource;

  const AddressExplorerRepositoryImpl({required this._datasource});

  @override
  Future<Result<AddressOverview, AddressViewFailure>> fetchOverview({
    required String address,
    required Network network,
  }) async {
    if (network.isLiquid) {
      return const Err(AddressViewUnsupportedNetworkFailure());
    }
    try {
      final model = await _datasource.fetch(address: address, network: network);
      return Ok(model.toEntity(address: address, network: network));
    } on AddressNetworkUnsupportedException {
      return const Err(AddressViewUnsupportedNetworkFailure());
    } on AddressInvalidException {
      return const Err(AddressViewInvalidAddressFailure());
    } catch (e) {
      log.warning('Address explorer: lookup failed (${e.runtimeType})');
      return Err(AddressViewServerUnreachableFailure('${e.runtimeType}'));
    }
  }
}
