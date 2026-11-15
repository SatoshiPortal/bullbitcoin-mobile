import 'package:bb_mobile/features/address_view/domain/address_overview.dart';
import 'package:bb_mobile/features/address_view/domain/address_view_failure.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;

abstract interface class AddressExplorerRepository {
  @useResult
  Future<Result<AddressOverview, AddressViewFailure>> fetchOverview({
    required String address,
    required Network network,
  });
}
