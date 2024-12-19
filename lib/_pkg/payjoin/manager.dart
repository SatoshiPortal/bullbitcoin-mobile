import 'dart:async';

import 'package:dio/dio.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart' as pj_uri;

class PayjoinManager {
  Future<Sender> initSender(
    String pjUriString,
    int networkFees,
    String originalPsbt,
  ) async {
    try {
      // TODO this is a super ugly hack because of ugliness in the bip21 module.
      // Fix that and get rid of this.
      final pjSubstring = pjUriString.substring(pjUriString.indexOf('pj=') + 3);
      final capitalizedPjSubstring = pjSubstring.toUpperCase();
      final pjUriStringWithCapitalizedPj =
          pjUriString.substring(0, pjUriString.indexOf('pj=') + 3) +
              capitalizedPjSubstring;
      // This should already be done before letting payjoin be enabled for sending
      final pjUri = (await pj_uri.Uri.fromStr(pjUriStringWithCapitalizedPj))
          .checkPjSupported();
      final minFeeRateSatPerKwu = BigInt.from(networkFees * 250);
      final senderBuilder = await SenderBuilder.fromPsbtAndUri(
        psbtBase64: originalPsbt,
        pjUri: pjUri,
      );
      final sender = await senderBuilder.buildRecommended(
        minFeeRate: minFeeRateSatPerKwu,
      );
      return sender;
    } catch (e) {
      throw Exception('Error initializing payjoin Sender: $e');
    }
  }

  /// Sends a payjoin using the v2 protocol given an initialized Sender.
  /// V2 protocol first attempts a v2 request, but if one cannot be extracted
  /// from the given bitcoin URI, it will attempt to send a v1 request.
  Future<String?> runPayjoinSender(Sender sender) async {
    final ohttpProxyUrl =
        await pj_uri.Url.fromStr('https://pj.bobspacebkk.com');
    Request postReq;
    V2PostContext postReqCtx;
    final dio = Dio();

    try {
      final result = await sender.extractV2(ohttpProxyUrl: ohttpProxyUrl);
      postReq = result.$1;
      postReqCtx = result.$2;
    } catch (e) {
      // extract v2 failed, attempt to send v1
      return await _runPayjoinSenderV1(sender, dio);
    }

    try {
      final postRes = await _postRequest(dio, postReq);
      final getCtx = await postReqCtx.processResponse(
        response: postRes.data as List<int>,
      );
      while (true) {
        try {
          final (getRequest, getReqCtx) = await getCtx.extractReq(
            ohttpRelay: ohttpProxyUrl,
          );
          final getRes = await _postRequest(dio, getRequest);
          return await getCtx.processResponse(
            response: getRes.data as List<int>,
            ohttpCtx: getReqCtx,
          );
        } catch (e) {
          // loop
        }
      }
    } catch (e) {
      throw Exception('Error polling payjoin sender: $e');
    }
  }

  // Attempt to send a payjoin using the v1 protocol as fallback.
  Future<String> _runPayjoinSenderV1(Sender sender, Dio dio) async {
    try {
      final (req, v1Ctx) = await sender.extractV1();
      final response = await _postRequest(dio, req);
      final proposalPsbt =
          await v1Ctx.processResponse(response: response.data as List<int>);
      return proposalPsbt;
    } catch (e) {
      throw Exception('Send V1 payjoin error: $e');
    }
  }

  /// Take a Request from the payjoin sender and post it over OHTTP.
  Future<Response<dynamic>> _postRequest(Dio dio, Request req) async {
    return await dio.post(
      req.url.asString(),
      options: Options(
        headers: {
          'Content-Type': req.contentType,
        },
        responseType: ResponseType.bytes,
      ),
      data: req.body,
    );
  }
}
