import 'dart:async';

import 'package:bb_mobile/_core/data/datasources/pdk_data_source.dart';
import 'package:bb_mobile/_core/data/models/pdk_payjoin_model.dart';
import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';

class PayjoinRepositoryImpl implements PayjoinRepository {
  final PdkDataSource _pdk;

  PayjoinRepositoryImpl({
    required PdkDataSource pdk,
  }) : _pdk = pdk;

  @override
  Stream<ReceivePayjoin> get requestedPayjoins => _pdk.requestedPayjoins.map(
        (event) => Payjoin.receiver(
          id: event.id,
          walletId: event.walletId,
        ) as ReceivePayjoin,
      );
  @override
  Stream<SendPayjoin> get sentProposals => _pdk.sentProposals.map(
        (event) => Payjoin.sender(
          uri: event.uri,
          walletId: event.walletId,
        ) as SendPayjoin,
      );

  @override
  Future<ReceivePayjoin> createReceivePayjoin({
    required String walletId,
    required String address,
    required bool isTestnet,
    int? expireAfterSec,
  }) async {
    final model = await _pdk.createReceiver(
      walletId: walletId,
      address: address,
      isTestnet: isTestnet,
      expireAfterSec: expireAfterSec,
    );

    final payjoin = Payjoin.receiver(
      id: model.id,
      walletId: walletId,
    );

    return payjoin as ReceivePayjoin;
  }

  @override
  Future<SendPayjoin> createSendPayjoin({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
    // Create the payjoin sender session
    final model = await _pdk.createSender(
      walletId: walletId,
      bip21: bip21,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
    );

    // Return a payjoin entity with send details
    final payjoin = Payjoin.sender(
      uri: model.uri,
      walletId: walletId,
    );

    return payjoin as SendPayjoin;
  }

  @override
  Future<List<Payjoin>> getAll({
    int? offset,
    int? limit,
    bool? completed,
  }) async {
    final models = await _pdk.getAll();

    final payjoins = models.map(
      (model) {
        if (model is PdkPayjoinReceiverModel) {
          return Payjoin.receiver(
            id: model.id,
            walletId: model.walletId,
          );
        } else {
          final sendModel = model as PdkPayjoinSenderModel;
          return Payjoin.sender(
            uri: sendModel.uri,
            walletId: sendModel.walletId,
          );
        }
      },
    ).toList();

    return payjoins;
  }
}
