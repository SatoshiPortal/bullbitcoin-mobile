import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinRepository {
  Stream<ReceivePayjoin> get requestedPayjoins;
  Stream<SendPayjoin> get sentProposals;
  Future<ReceivePayjoin> createReceivePayjoin({
    required String walletId,
    required bool isTestnet,
    required String address,
    int? expireAfterSec,
  });
  Future<SendPayjoin> createSendPayjoin({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  //Future<List<Payjoin>> getPayjoins({int? offset, int? limit, bool? completed});
}
