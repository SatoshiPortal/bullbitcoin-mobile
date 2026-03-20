import 'package:bb_mobile/core/dlc/domain/entities/dlc_contract.dart';
import 'package:bb_mobile/core/dlc/domain/entities/dlc_order.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';

class PlaceDlcOrderUsecase {
  PlaceDlcOrderUsecase({required DlcRepository dlcRepository})
      : _dlcRepository = dlcRepository;

  final DlcRepository _dlcRepository;

  /// [signedOfferHex] must be produced by the key-signing logic before calling this.
  Future<DlcOrder> execute({
    required DlcOptionType optionType,
    required DlcOrderSide side,
    required int strikePriceSat,
    required int premiumSat,
    required int quantity,
    required int expiryTimestamp,
    required String makerPubkey,
    required String signedOfferHex,
  }) =>
      _dlcRepository.placeOrder(
        optionType: optionType,
        side: side,
        strikePriceSat: strikePriceSat,
        premiumSat: premiumSat,
        quantity: quantity,
        expiryTimestamp: expiryTimestamp,
        makerPubkey: makerPubkey,
        signedOfferHex: signedOfferHex,
      );
}
