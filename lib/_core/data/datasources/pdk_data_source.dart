import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/_core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/_core/data/models/pdk_payjoin_model.dart';
import 'package:dio/dio.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart';

abstract class PdkDataSource {
  Stream<PdkReceivePayjoinModel> get requestedPayjoins;
  Stream<PdkSendPayjoinModel> get sentProposals;
  Future<PdkReceivePayjoinModel> createReceiver({
    required String walletId,
    required String address,
    bool isTestnet = false,
    int? expireAfterSec,
  });
  Future<PdkSendPayjoinModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  Future<PdkPayjoinModel?> get(String id);
  Future<List<PdkPayjoinModel>> getAll();
  Future<void> delete(String id);
}

class PdkDataSourceImpl implements PdkDataSource {
  final String _ohttpRelayUrl;
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final KeyValueStorageDataSource<String> _storage;
  final StreamController<PdkReceivePayjoinModel> _payjoinRequestedController =
      StreamController.broadcast();
  final StreamController<PdkSendPayjoinModel> _proposalSentController =
      StreamController.broadcast();

  PdkDataSourceImpl({
    String ohttpRelayUrl = 'https://pj.bobspacebkk.com',
    String payjoinDirectoryUrl = 'https://payjo.in',
    required Dio dio,
    required KeyValueStorageDataSource<String> storage,
  })  : _ohttpRelayUrl = ohttpRelayUrl,
        _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio,
        _storage = storage;

  @override
  Stream<PdkReceivePayjoinModel> get requestedPayjoins =>
      _payjoinRequestedController.stream.asBroadcastStream();

  @override
  Stream<PdkSendPayjoinModel> get sentProposals =>
      _proposalSentController.stream.asBroadcastStream();

  @override
  Future<PdkReceivePayjoinModel> createReceiver({
    required String walletId,
    required String address,
    bool isTestnet = false,
    int? expireAfterSec,
  }) async {
    try {
      final payjoinDirectory = await Url.fromStr(_payjoinDirectoryUrl);
      final ohttpRelay = await Url.fromStr(_ohttpRelayUrl);
      final ohttpKeys = await fetchOhttpKeys(
        ohttpRelay: ohttpRelay,
        payjoinDirectory: payjoinDirectory,
      );

      final receiver = await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: ohttpRelay,
        expireAfter:
            expireAfterSec == null ? null : BigInt.from(expireAfterSec),
      );

      final pjUrl = await receiver.pjUrl();
      final model = PdkPayjoinModel.receive(
        id: receiver.id(),
        receiver: receiver.toJson(),
        walletId: walletId,
        pjUrl: pjUrl.asString(),
      ) as PdkReceivePayjoinModel;

      await _store(model);

      // TODO: Start listening for original psbt in isolate

      return model;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  @override
  Future<PdkSendPayjoinModel> createSender({
    required String walletId,
    required String bip21,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
    final uri = await Uri.fromStr(bip21);

    PjUri pjUri;
    try {
      pjUri = uri.checkPjSupported();
    } catch (e) {
      throw NoValidPayjoinBip21Exception(e.toString());
    }

    final minFeeRateSatPerKwu = BigInt.from(networkFeesSatPerVb * 250);
    final senderBuilder = await SenderBuilder.fromPsbtAndUri(
      psbtBase64: originalPsbt,
      pjUri: pjUri,
    );
    final sender = await senderBuilder.buildRecommended(
      minFeeRate: minFeeRateSatPerKwu,
    );

    final model = PdkPayjoinModel.send(
      uri: uri.asString(),
      sender: sender.toJson(),
      walletId: walletId,
      originalPsbt: originalPsbt,
    ) as PdkSendPayjoinModel;

    await _store(model);

    // TODO: Start listening for proposals in isolate

    return model;
  }

  Future<void> _store(PdkPayjoinModel model) async {
    final value = jsonEncode(model.toJson());
    if (model is PdkReceivePayjoinModel) {
      await _storage.saveValue(key: model.id, value: value);
    } else if (model is PdkSendPayjoinModel) {
      await _storage.saveValue(key: model.uri, value: value);
    }
  }

  @override
  Future<PdkPayjoinModel?> get(String id) async {
    final value = await _storage.getValue(id);
    if (value == null) {
      return null;
    }
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['uri'] != null) {
      return PdkSendPayjoinModel.fromJson(json);
    } else {
      return PdkReceivePayjoinModel.fromJson(json);
    }
  }

  @override
  Future<List<PdkPayjoinModel>> getAll() async {
    final entries = await _storage.getAll();
    final models = <PdkPayjoinModel>[];

    for (final value in entries.values) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      if (json['uri'] != null) {
        models.add(PdkSendPayjoinModel.fromJson(json));
      } else {
        models.add(PdkReceivePayjoinModel.fromJson(json));
      }
    }
    return models;
  }

  @override
  Future<void> delete(String id) async {
    await _storage.deleteValue(id);
  }

  /*
  Future<V2GetContext> _request({
    required Sender sender,
  }) async {
    final (req, context) = await sender.extractV2(
      ohttpProxyUrl: await Url.fromStr(_ohttpRelayUrl),
    );

    final res = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
        responseType: ResponseType.bytes,
      ),
    );

    final getCtx = await context.processResponse(
      response: res.data as List<int>,
    );

    return getCtx;
  }

  @override
  Future<UncheckedProposal?> getRequest({
    required PdkReceivePayjoinModel payjoin,
  }) async {
    final receiver = Receiver.fromJson(payjoin.receiver);
    final (req, context) = await receiver.extractReq();
    final ohttpResponse = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
        responseType: ResponseType.bytes,
      ),
    );
    final proposal = await receiver.processRes(
      body: ohttpResponse.data as List<int>,
      ctx: context,
    );

    return proposal;
  }

  Future<void> _proposePayjoin(
    PayjoinProposal proposal,
  ) async {
    final (req, ohttpCtx) = await proposal.extractV2Req();
    final res = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
        responseType: ResponseType.bytes,
      ),
    );
    await proposal.processRes(
      res: res.data as List<int>,
      ohttpContext: ohttpCtx,
    );
  }

  Future<String?> _getProposalPsbt({required V2GetContext context}) async {
    final (req, reqCtx) =
        await context.extractReq(ohttpRelay: await Url.fromStr(_ohttpRelayUrl));

    final res = await _dio.post(
      req.url.asString(),
      data: req.body,
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
        responseType: ResponseType.bytes,
      ),
    );

    final proposalPsbt = await context.processResponse(
      response: res.data as List<int>,
      ohttpCtx: reqCtx,
    );

    return proposalPsbt;
  }*/
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}
