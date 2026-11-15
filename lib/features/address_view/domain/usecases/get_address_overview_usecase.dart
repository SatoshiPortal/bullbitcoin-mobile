import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/address_explorer_repository.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

class GetAddressOverviewUsecase {
  final AddressExplorerRepository _repository;

  const GetAddressOverviewUsecase({required this._repository});

  @useResult
  Future<Result<AddressOverview, AddressViewFailure>> execute({
    required String address,
    required Network network,
  }) => _repository.fetchOverview(address: address, network: network);
}
