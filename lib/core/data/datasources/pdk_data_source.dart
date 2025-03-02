import 'package:bb_mobile/core/data/datasources/key_value_stores/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/data/models/pdk_receive_payjoin_model.dart';
import 'package:bb_mobile/core/data/models/pdk_send_payjoin_model.dart';
import 'package:dio/dio.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart';

abstract class PdkDataSource {
  Stream<(PdkReceivePayjoinModel, UncheckedProposal)> get receiverStream;
  Stream<PdkSendPayjoinModel> get senderStream;
  Future<Receiver> createReceiver({
    required String walletId,
    required String address,
    bool isTestnet = false,
    int? expireAfterSec,
  });
  Future<Uri> parseBip21Uri(String bip21);
  Future<Sender> createSender({
    required String walletId,
    required Uri uri,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  });
  Future<void> request({
    required Sender sender,
  });
  Future<UncheckedProposal?> checkForRequest({
    required Receiver receiver,
  });
  Future<void> proposePayjoin(
    PayjoinProposal proposal,
  );
  Future<String?> checkForProposalPsbt({required V2GetContext context});
  Future<void> resumeSessions();
}

class PdkDataSourceImpl implements PdkDataSource {
  final String _ohttpRelayUrl;
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final KeyValueStorageDataSource<String> _storage;

  const PdkDataSourceImpl({
    String ohttpRelayUrl = 'https://pj.bobspacebkk.com',
    String payjoinDirectoryUrl = 'https://payjo.in',
    required Dio dio,
    required KeyValueStorageDataSource<String> storage,
  })  : _ohttpRelayUrl = ohttpRelayUrl,
        _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio,
        _storage = storage;

  @override
  // TODO: implement receiverStream
  Stream<(PdkReceivePayjoinModel, UncheckedProposal)> get receiverStream =>
      throw UnimplementedError();

  @override
  // TODO: implement senderStream
  Stream<PdkSendPayjoinModel> get senderStream => throw UnimplementedError();

  @override
  Future<Receiver> createReceiver({
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

      // TODO: create receiver model
      // TODO: Save model to storage
      // TODO: Start listening for original psbt in isolate

      return receiver;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  @override
  Future<Uri> parseBip21Uri(String bip21) async {
    final uri = await Uri.fromStr(bip21);
    return uri;
  }

  @override
  Future<Sender> createSender({
    required String walletId,
    required Uri uri,
    required String originalPsbt,
    required double networkFeesSatPerVb,
  }) async {
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

    // TODO: create sender model
    // TODO: Save model to storage
    // TODO: Start listening for proposals in isolate

    return sender;
  }

  @override
  Future<V2GetContext> request({
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
  Future<UncheckedProposal?> checkForRequest({
    required Receiver receiver,
  }) async {
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

  @override
  Future<void> proposePayjoin(
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

  @override
  Future<String?> checkForProposalPsbt({required V2GetContext context}) async {
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
  }

  @override
  Future<void> resumeSessions() async {}
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}
