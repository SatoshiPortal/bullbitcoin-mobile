import 'package:dio/dio.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart';

abstract class PdkDataSource {
  Stream<(Receiver, UncheckedProposal)> get receiverStream;
  Stream<(Sender, String)> get senderStream;
  Future<Receiver> createReceiver({
    required String address,
    bool isTestnet = false,
    int? expireAfterSec,
  });
  Future<Sender> createSender({
    required String bip21,
    required String originalPsbt,
    required int networkFeesSatPerVb,
  });
  Future<void> resumeReceiver({
    required Receiver receiver,
  });
  Future<void> resumeSender({
    required Sender sender,
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
}

class PdkDataSourceImpl implements PdkDataSource {
  final String _ohttpRelayUrl;
  final String _payjoinDirectoryUrl;
  final Dio _dio;

  const PdkDataSourceImpl({
    String ohttpRelayUrl = 'https://pj.bobspacebkk.com',
    String payjoinDirectoryUrl = 'https://payjo.in',
    required Dio dio,
  })  : _ohttpRelayUrl = ohttpRelayUrl,
        _payjoinDirectoryUrl = payjoinDirectoryUrl,
        _dio = dio;

  @override
  Future<Receiver> createReceiver({
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
      return await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: ohttpRelay,
        expireAfter:
            expireAfterSec == null ? null : BigInt.from(expireAfterSec),
      );
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  @override
  Future<Sender> createSender({
    required String bip21,
    required String originalPsbt,
    required int networkFeesSatPerVb,
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
}

class ReceiveCreationException implements Exception {
  final String message;

  ReceiveCreationException(this.message);
}

class NoValidPayjoinBip21Exception implements Exception {
  final String message;

  NoValidPayjoinBip21Exception(this.message);
}
