import 'dart:async';
import 'dart:typed_data';

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
  Stream<ReceivePayjoin> get payjoinRequestedStream =>
      _pdk.payjoinRequestedStream.map(
        (event) => Payjoin.receive(
          id: event.id,
          walletId: event.walletId,
        ) as ReceivePayjoin,
      );
  @override
  Stream<SendPayjoin> get proposalSentStream => _pdk.proposalSentStream.map(
        (event) => Payjoin.send(
          bip21: event.uri,
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

    // Store the payjoin model for later resuming
    await _pdk.store(model);

    final payjoin = Payjoin.receive(
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
    final uri = await _pdk.parseBip21Uri(bip21);

    // Create the payjoin sender session
    final model = await _pdk.createSender(
      walletId: walletId,
      uri: uri,
      originalPsbt: originalPsbt,
      networkFeesSatPerVb: networkFeesSatPerVb,
    );

    // Store the payjoin model for later resuming
    await _pdk.store(model);

    // Return a payjoin entity with send details
    final payjoin = Payjoin.send(
      bip21: model.uri,
      walletId: walletId,
    );

    return payjoin as SendPayjoin;
  }

  @override
  Future<void> processPayjoinRequest(
    ReceivePayjoin payjoin, {
    required Future<bool> Function(Uint8List) isMine,
  }) async {
    final model = await _pdk.get(payjoin.id);
    if (model == null) {
      throw PayjoinNotFoundException(payjoin.id);
    }

    final result = await _pdk.processRequest(
      payjoin: model as PdkReceivePayjoinModel,
    );

    // TODO: get the needed values from the result model and add them to the payjoin entity
    final payjoinResult = payjoin.copyWith();

    // TODO: add Payjoin event on a Stream to notify other parts of the application of the processed payjoin
  }

  @override
  Future<void> processPayjoinProposal(
    SendPayjoin payjoin,
  ) async {
    final model = await _pdk.get(payjoin.bip21);
    if (model == null) {
      throw PayjoinNotFoundException(payjoin.bip21);
    }

    final result = await _pdk.processProposal(
      payjoin: model as PdkSendPayjoinModel,
    );

    // TODO: get the needed values from the result model and add them to the payjoin entity
    final payjoinResult = payjoin.copyWith();

    // TODO: add Payjoin event on a Stream to notify other parts of the application about the processed payjoin
  }

  @override
  Future<void> resumeSessions() async {
    final payjoins = await _pdk.getAll();
    for (final payjoin in payjoins) {
      await _pdk.resumePayjoin(payjoin);
    }
  }
}

class PayjoinNotFoundException implements Exception {
  final String id;

  PayjoinNotFoundException(this.id);
}
