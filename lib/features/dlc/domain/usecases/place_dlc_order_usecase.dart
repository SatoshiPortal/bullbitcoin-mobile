import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class PlaceDlcOrderUsecase {
  PlaceDlcOrderUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// Places a maker order on the DLC coordinator.
  /// [fundingPubkeyHex] must come from the user's wallet.
  Future<Map<String, dynamic>> execute({
    required String instrumentId,
    required DlcOrderSide side,
    required int quantity,
    required int price,
    required String fundingPubkeyHex,
    String? idempotencyKey,
  }) =>
      _dlcRepository.placeOrder(
        instrumentId: instrumentId,
        side: side,
        quantity: quantity,
        price: price,
        fundingPubkeyHex: fundingPubkeyHex,
        idempotencyKey: idempotencyKey,
      );
}
