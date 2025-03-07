import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinService {
  Stream<Payjoin> get payjoins;
  Future<Payjoin> createPayjoinReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    int? expireAfterSec,
  });
  Future<Payjoin> createPayjoinSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
}
