import 'dart:typed_data';

import 'package:bb_mobile/_core/domain/entities/payjoin.dart';

abstract class PayjoinRepository {
  Stream<ReceivePayjoin> get payjoinRequestedStream;
  Stream<SendPayjoin> get proposalSentStream;
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
  Future<void> processPayjoinRequest(
    ReceivePayjoin payjoin, {
    // TODO: add callback functions to handle wallet and blockchain operations
    required Future<bool> Function(Uint8List) isMine,
  });
  Future<void> processPayjoinProposal(
    SendPayjoin payjoin,
    // TODO: add callback functions to handle wallet and blockchain operations
  );
  Future<void> resumeSessions();
  //Future<List<Payjoin>> getPayjoins({int? offset, int? limit, bool? completed});
}
