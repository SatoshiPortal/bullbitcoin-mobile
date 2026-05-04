import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_input_pair_model.dart';
import 'package:bb_mobile/core/payjoin/data/models/payjoin_model.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' as logger;
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:payjoin/payjoin.dart';
import 'package:payjoin/http.dart' show fetchOhttpKeys;

class PdkPayjoinDatasource {
  final String _payjoinDirectoryUrl;
  final Dio _dio;
  final StreamController<PayjoinReceiverModel> _payjoinRequestedController;
  final StreamController<PayjoinSenderModel> _proposalSentController;
  final StreamController<PayjoinModel> _expiredController;

  // Per-session polling timers keyed by session id
  final Map<String, Timer> _receiverTimers = {};
  final Map<String, Timer> _senderTimers = {};

  PdkPayjoinDatasource({
    String payjoinDirectoryUrl = PayjoinConstants.directoryUrl,
    required Dio dio,
  }) : _payjoinDirectoryUrl = payjoinDirectoryUrl,
       _dio = dio,
       _payjoinRequestedController = StreamController.broadcast(),
       _proposalSentController = StreamController.broadcast(),
       _expiredController = StreamController.broadcast();

  Stream<PayjoinReceiverModel> get requestsForReceivers =>
      _payjoinRequestedController.stream;

  Stream<PayjoinSenderModel> get proposalsForSenders =>
      _proposalSentController.stream;

  Stream<PayjoinModel> get expiredPayjoins => _expiredController.stream;

  Future<(OhttpKeys?, String?)> fetchOhttpKeyAndRelay({
    required String payjoinDirectory,
  }) async {
    for (final ohttpRelayUrl in PayjoinConstants.ohttpRelayUrls) {
      try {
        final ohttpKeys = await fetchOhttpKeys(
          ohttpRelayUrl: ohttpRelayUrl,
          directoryUrl: payjoinDirectory,
        );
        return (ohttpKeys, ohttpRelayUrl);
      } catch (e) {
        continue;
      }
    }
    return (null, null);
  }

  Future<PayjoinReceiverModel> createReceiver({
    required String walletId,
    required String address,
    required bool isTestnet,
    required BigInt maxFeeRateSatPerVb,
    required int expireAfterSec,
  }) async {
    try {
      final (ohttpKeys, ohttpRelay) = await fetchOhttpKeyAndRelay(
        payjoinDirectory: _payjoinDirectoryUrl,
      );

      if (ohttpRelay == null || ohttpKeys == null) {
        throw Exception('All OHTTP relays failed');
      }

      var receiverBuilder =
          ReceiverBuilder(
                address: address,
                directory: _payjoinDirectoryUrl,
                ohttpKeys: ohttpKeys,
              )
              .withExpiration(expiration: expireAfterSec)
              .withMaxFeeRate(
                maxEffectiveFeeRateSatPerVb: maxFeeRateSatPerVb.toInt(),
              );

      final persister = InMemoryJsonReceiverSessionPersister();
      final initialized = receiverBuilder.build().save(persister: persister);
      final pjUri = initialized.pjUri().asString();
      // Derive the receiver ID from pjUri
      final id = sha256.convert(utf8.encode(pjUri)).toString().substring(0, 16);

      // Create and store the model to keep track of the payjoin session
      final model =
          PayjoinModel.receiver(
                id: id,
                address: address,
                isTestnet: isTestnet,
                receiver: persister.toJson(),
                walletId: walletId,
                pjUri: pjUri,
                maxFeeRateSatPerVb: maxFeeRateSatPerVb,
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                expireAfterSec: expireAfterSec,
              )
              as PayjoinReceiverModel;

      // Start listening for a payjoin request from the sender
      startListeningForRequest(model);

      return model;
    } catch (e) {
      throw ReceiveCreationException(e.toString());
    }
  }

  Future<PayjoinSenderModel> createSender({
    required String walletId,
    required bool isTestnet,
    required String bip21,
    required String originalPsbt,
    required int amountSat,
    required double networkFeesSatPerVb,
    int? expireAfterSec,
  }) async {
    final expirySec = expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec;

    PjUri pjUri;
    final Uri parsedUri;
    try {
      parsedUri = Uri.parse(uri: bip21);
      pjUri = parsedUri.checkPjSupported();
    } catch (e) {
      throw NoValidPayjoinBip21Exception(e.toString());
    }

    var sendBuilder = SenderBuilder(psbt: originalPsbt, uri: pjUri);
    final persister = InMemoryJsonSenderSessionPersister();
    final minFeeRateSatPerKwu = (networkFeesSatPerVb * 250).round();
    WithReplyKey? withReplyKey;
    try {
      withReplyKey = sendBuilder
          .buildRecommended(minFeeRate: minFeeRateSatPerKwu)
          .save(persister: persister);
    } catch (e) {
      throw SendCreationException(e.toString());
    }

    await postOriginalProposal(withReplyKey, persister);

    // Create and store the model with the data needed to keep track of the
    // payjoin session
    final model =
        PayjoinModel.sender(
              uri: parsedUri.asString(),
              isTestnet: isTestnet,
              sender: persister.toJson(),
              walletId: walletId,
              originalPsbt: originalPsbt,
              originalTxId: (await BitcoinTx.fromPsbt(originalPsbt)).txid,
              amountSat: amountSat,
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              expireAfterSec: expirySec,
            )
            as PayjoinSenderModel;

    // Start listening for a payjoin proposal from the receiver
    startListeningForProposal(model);

    return model;
  }

  Future<void> postOriginalProposal(
    WithReplyKey withReplyKey,
    InMemoryJsonSenderSessionPersister persister,
  ) async {
    Object? lastError;
    var posted = false;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final reqCtx = withReplyKey.createV2PostRequest(ohttpRelay: relay);
        final body = await _postBytes(
          _dio,
          reqCtx.request.url,
          reqCtx.request.body,
          reqCtx.request.contentType,
        );
        withReplyKey
            .processResponse(response: body, postCtx: reqCtx.ohttpCtx)
            .save(persister: persister);
        posted = true;
        break;
      } catch (e) {
        log('sender v2 post via $relay failed: $e');
        lastError = e;
        continue;
      }
    }
    if (!posted) {
      throw SendCreationException(
        'Failed to post original PSBT to any OHTTP relay: $lastError',
      );
    }
  }

  Future<PayjoinReceiverModel> proposePayjoin({
    required PayjoinReceiverModel receiverModel,
    required bool Function(Uint8List) hasOwnedInputs,
    required bool Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required String Function(String) processPsbt,
  }) async {
    final persister = InMemoryJsonReceiverSessionPersister.fromJson(
      receiverModel.receiver,
    );
    final state = replayReceiverEventLog(persister: persister).state();

    final result = await processReceiveSession(
      state: state,
      persister: persister,
      hasOwnedInputs: hasOwnedInputs,
      hasReceiverOutput: hasReceiverOutput,
      inputPairs: inputPairs,
      receiverModel: receiverModel,
      processPsbt: processPsbt,
    );

    // Update the model with the proposal psbt so it can be known a proposal has
    //  been sent
    final proposalPsbt = result.psbt;

    final updatedModel = receiverModel.copyWith(
      receiver: persister.toJson(),
      proposalPsbt: proposalPsbt,
      txId: (await BitcoinTx.fromPsbt(proposalPsbt)).txid,
    );

    logger.log.info(
      'Payjoin request processed and proposal sent for ${receiverModel.id}: $proposalPsbt',
    );

    return updatedModel;
  }

  Future<({Monitor monitor, String psbt})> processReceiveSession({
    required ReceiveSession state,
    required InMemoryJsonReceiverSessionPersister persister,
    required bool Function(Uint8List) hasOwnedInputs,
    required bool Function(Uint8List) hasReceiverOutput,
    required List<PayjoinInputPairModel> inputPairs,
    required PayjoinReceiverModel receiverModel,
    required String Function(String) processPsbt,
  }) async {
    switch (state) {
      case InitializedReceiveSession():
        throw StateError(
          'Original PSBT is retrieved in startListeningForRequest',
        );
      case UncheckedOriginalPayloadReceiveSession():
        return _checkProposal(
          state.inner,
          persister,
          hasOwnedInputs,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case MaybeInputsOwnedReceiveSession():
        return _checkInputsNotOwned(
          state.inner,
          persister,
          hasOwnedInputs,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case MaybeInputsSeenReceiveSession():
        return _checkNoInputsSeenBefore(
          state.inner,
          persister,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case OutputsUnknownReceiveSession():
        return _identifyReceiverOutputs(
          state.inner,
          persister,
          hasReceiverOutput,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsOutputsReceiveSession():
        return _commitOutputs(
          state.inner,
          persister,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsInputsReceiveSession():
        return _contributeInputs(
          state.inner,
          persister,
          inputPairs,
          receiverModel,
          processPsbt,
        );
      case WantsFeeRangeReceiveSession():
        return _applyFeeRange(
          state.inner,
          persister,
          receiverModel,
          processPsbt,
        );
      case ProvisionalProposalReceiveSession():
        return _finalizeProposal(state.inner, persister, processPsbt);
      case PayjoinProposalReceiveSession():
        return _sendPayjoinProposal(state.inner, persister);
      case HasReplyableExceptionReceiveSession():
        throw StateError('Receive session has a replyable exception');
      case MonitorReceiveSession():
        throw StateError(
          'Receive session is monitoring; proposal already sent',
        );
      case ClosedReceiveSession():
        throw StateError('Receive session is closed');
      default:
        throw StateError('Unexpected receive session state: $state');
    }
  }

  Future<({Monitor monitor, String psbt})> _checkProposal(
    UncheckedOriginalPayload inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasOwnedInputs,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner.assumeInteractiveReceiver().save(persister: persister);
    return _checkInputsNotOwned(
      next,
      persister,
      hasOwnedInputs,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _checkInputsNotOwned(
    MaybeInputsOwned inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasOwnedInputs,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .checkInputsNotOwned(isOwned: _IsScriptOwned(hasOwnedInputs))
        .save(persister: persister);
    return _checkNoInputsSeenBefore(
      next,
      persister,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _checkNoInputsSeenBefore(
    MaybeInputsSeen inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .checkNoInputsSeenBefore(isKnown: _AssumeUnseen())
        .save(persister: persister);
    return _identifyReceiverOutputs(
      next,
      persister,
      hasReceiverOutput,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _identifyReceiverOutputs(
    OutputsUnknown inner,
    InMemoryJsonReceiverSessionPersister persister,
    bool Function(Uint8List) hasReceiverOutput,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .identifyReceiverOutputs(
          isReceiverOutput: _IsScriptOwned(hasReceiverOutput),
        )
        .save(persister: persister);
    return _commitOutputs(
      next,
      persister,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _commitOutputs(
    WantsOutputs inner,
    InMemoryJsonReceiverSessionPersister persister,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner.commitOutputs().save(persister: persister);
    return _contributeInputs(
      next,
      persister,
      inputPairs,
      receiverModel,
      processPsbt,
    );
  }

  Future<({Monitor monitor, String psbt})> _contributeInputs(
    WantsInputs inner,
    InMemoryJsonReceiverSessionPersister persister,
    List<PayjoinInputPairModel> inputPairs,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final candidates = inputPairs.map(_buildInputPair).toList();
    InputPair? chosen;
    try {
      chosen = inner.tryPreservingPrivacy(candidateInputs: candidates);
    } catch (e) {
      throw StateError('No inputs available to contribute to payjoin');
    }
    final next = inner
        .contributeInputs(replacementInputs: [chosen])
        .commitInputs()
        .save(persister: persister);
    return _applyFeeRange(next, persister, receiverModel, processPsbt);
  }

  Future<({Monitor monitor, String psbt})> _applyFeeRange(
    WantsFeeRange inner,
    InMemoryJsonReceiverSessionPersister persister,
    PayjoinReceiverModel receiverModel,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .applyFeeRange(
          minFeeRateSatPerVb: null,
          maxEffectiveFeeRateSatPerVb: receiverModel.maxFeeRateSatPerVb.toInt(),
        )
        .save(persister: persister);
    return _finalizeProposal(next, persister, processPsbt);
  }

  Future<({Monitor monitor, String psbt})> _finalizeProposal(
    ProvisionalProposal inner,
    InMemoryJsonReceiverSessionPersister persister,
    String Function(String) processPsbt,
  ) async {
    final next = inner
        .finalizeProposal(processPsbt: _ProcessPsbt(processPsbt))
        .save(persister: persister);
    return _sendPayjoinProposal(next, persister);
  }

  Future<({Monitor monitor, String psbt})> _sendPayjoinProposal(
    PayjoinProposal proposal,
    InMemoryJsonReceiverSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final req = proposal.createPostRequest(ohttpRelay: relay);
        final body = await _postBytes(
          _dio,
          req.request.url,
          req.request.body,
          req.request.contentType,
        );
        // Capture the proposal PSBT here, as it's not available on the monitor typestate.
        final psbt = proposal.psbt();
        final monitor = proposal
            .processResponse(body: body, ohttpContext: req.clientResponse)
            .save(persister: persister);
        return (monitor: monitor, psbt: psbt);
      } catch (e) {
        log('proposal post via $relay failed: $e');
        lastError = e;
        continue;
      }
    }
    throw PayjoinNotFoundException(
      'Failed to post payjoin proposal: $lastError',
    );
  }

  InputPair _buildInputPair(PayjoinInputPairModel input) {
    return InputPair(
      txin: PlainTxIn(
        previousOutput: PlainOutPoint(txid: input.txId, vout: input.vout),
        scriptSig: Uint8List.fromList(input.scriptSigRawOutputScript),
        sequence: input.sequence,
        witness: input.witness,
      ),
      psbtin: PlainPsbtInput(
        witnessUtxo: PlainTxOut(
          valueSat: (input.value ?? BigInt.zero).toInt(),
          scriptPubkey: input.scriptPubkey,
        ),
        redeemScript: input.redeemScriptRawOutputScript.isEmpty
            ? null
            : Uint8List.fromList(input.redeemScriptRawOutputScript),
        witnessScript: input.witnessScriptRawOutputScript.isEmpty
            ? null
            : Uint8List.fromList(input.witnessScriptRawOutputScript),
      ),
      expectedWeight: null,
    );
  }

  void startListeningForRequest(PayjoinReceiverModel payjoin) {
    _receiverTimers[payjoin.id]?.cancel();
    _receiverTimers[payjoin.id] = Timer.periodic(
      const Duration(seconds: PayjoinConstants.directoryPollingInterval),
      (timer) => _pollReceiverOnce(payjoin, timer),
    );
  }

  void startListeningForProposal(PayjoinSenderModel payjoin) {
    _senderTimers[payjoin.id]?.cancel();
    _senderTimers[payjoin.id] = Timer.periodic(
      const Duration(seconds: PayjoinConstants.directoryPollingInterval),
      (timer) => _pollSenderOnce(payjoin, timer),
    );
  }

  Future<void> _pollReceiverOnce(
    PayjoinReceiverModel receiverModel,
    Timer timer,
  ) async {
    log('[receiver poll] checking for request for ${receiverModel.id}');
    try {
      final persister = InMemoryJsonReceiverSessionPersister.fromJson(
        receiverModel.receiver,
      );
      final ReceiveSession state;
      try {
        state = replayReceiverEventLog(persister: persister).state();
      } on ReceiverReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin receiver expired: $e');
        }
        rethrow;
      }
      if (state is! InitializedReceiveSession) return;

      final unchecked = await _getUncheckedOriginalPayload(
        state.inner,
        persister,
      );
      if (unchecked == null) {
        log('[receiver poll] no request yet for ${receiverModel.id}');
        return;
      }

      timer.cancel();
      _receiverTimers.remove(receiverModel.id);

      final maybeInputsOwned = unchecked.assumeInteractiveReceiver().save(
        persister: persister,
      );
      final originalTxBytes = maybeInputsOwned.extractTxToScheduleBroadcast();
      final originalTx = await BitcoinTx.fromBytes(originalTxBytes);
      final amountSat = await originalTx.getAmountReceived(
        address: receiverModel.address,
        isTestnet: receiverModel.isTestnet,
      );
      log(
        '[receiver poll] request found for ${receiverModel.id}: '
        'txid=${originalTx.txid} amount=$amountSat',
      );
      final updatedModel = receiverModel.copyWith(
        receiver: persister.toJson(),
        originalTxBytes: originalTxBytes,
        originalTxId: originalTx.txid,
        amountSat: amountSat,
      );
      _payjoinRequestedController.add(updatedModel);
    } on PayjoinExpiredException catch (e) {
      logger.log.info('[receiver poll] expired for ${receiverModel.id}: $e');
      timer.cancel();
      _receiverTimers.remove(receiverModel.id);
      _expiredController.add(receiverModel.copyWith(isExpired: true));
    } catch (e) {
      logger.log.info('[receiver poll] ${receiverModel.id}: $e');
    }
  }

  Future<void> _pollSenderOnce(
    PayjoinSenderModel senderModel,
    Timer timer,
  ) async {
    log('[sender poll] checking for proposal for ${senderModel.id}');
    try {
      final persister = InMemoryJsonSenderSessionPersister.fromJson(
        senderModel.sender,
      );
      final SendSession state;
      try {
        state = replaySenderEventLog(persister: persister).state();
      } on SenderReplayException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin sender expired: $e');
        }
        rethrow;
      }
      if (state is! PollingForProposalSendSession) return;

      final proposalPsbt = await _getProposalPsbt(state.inner, persister);
      if (proposalPsbt == null) return;

      timer.cancel();
      _senderTimers.remove(senderModel.id);

      log('[sender poll] proposal found for ${senderModel.id}');
      final txId = (await BitcoinTx.fromPsbt(proposalPsbt)).txid;
      final updatedModel = senderModel.copyWith(
        sender: persister.toJson(),
        proposalPsbt: proposalPsbt,
        txId: txId,
      );
      _proposalSentController.add(updatedModel);
    } on PayjoinExpiredException catch (e) {
      logger.log.info('[sender poll] expired for ${senderModel.id}: $e');
      timer.cancel();
      _senderTimers.remove(senderModel.id);
      _expiredController.add(senderModel.copyWith(isExpired: true));
    } catch (e) {
      logger.log.info('[sender poll] ${senderModel.id}: $e');
    }
  }

  Future<UncheckedOriginalPayload?> _getUncheckedOriginalPayload(
    Initialized initialized,
    InMemoryJsonReceiverSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final poll = initialized.createPollRequest(ohttpRelay: relay);
        final body = await _postBytes(
          _dio,
          poll.request.url,
          poll.request.body,
          poll.request.contentType,
        );
        final outcome = initialized
            .processResponse(body: body, ctx: poll.clientResponse)
            .save(persister: persister);
        if (outcome is StasisInitializedTransitionOutcome) return null;
        return (outcome as ProgressInitializedTransitionOutcome).inner;
      } on ReceiverException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin receiver expired: $e');
        }
        log('receiver createPollRequest via $relay failed: $e');
        lastError = e;
        continue;
      } catch (e) {
        log('receiver poll via $relay failed: $e');
        lastError = e;
        continue;
      }
    }
    throw PayjoinNotFoundException('Failed to poll receiver: $lastError');
  }

  Future<String?> _getProposalPsbt(
    PollingForProposal polling,
    InMemoryJsonSenderSessionPersister persister,
  ) async {
    Object? lastError;
    for (final relay in PayjoinConstants.ohttpRelayUrls) {
      try {
        final poll = polling.createPollRequest(ohttpRelay: relay);
        final body = await _postBytes(
          _dio,
          poll.request.url,
          poll.request.body,
          poll.request.contentType,
        );
        final outcome = polling
            .processResponse(response: body, ohttpCtx: poll.ohttpCtx)
            .save(persister: persister);
        if (outcome is StasisPollingForProposalTransitionOutcome) {
          return null;
        }
        return (outcome as ProgressPollingForProposalTransitionOutcome)
            .psbtBase64;
      } on CreateRequestException catch (e) {
        if (_isExpiredString(e)) {
          throw PayjoinExpiredException('Payjoin sender expired: $e');
        }
        log('sender createPollRequest via $relay failed: $e');
        lastError = e;
        continue;
      } catch (e) {
        log('sender poll via $relay failed: $e');
        lastError = e;
        continue;
      }
    }
    throw PayjoinNotFoundException('Failed to poll sender: $lastError');
  }

  // "Expired" variants aren't exposed publicly as a distinct subtype.
  // Tighten to a typed check if the payjoin bindings start exposing variants.
  static bool _isExpiredString(Object error) =>
      error.toString().toLowerCase().contains('expired');

  static Future<Uint8List> _postBytes(
    Dio dio,
    String url,
    Uint8List body,
    String contentType,
  ) async {
    final response = await dio.post<List<int>>(
      url,
      data: body,
      options: Options(
        headers: {'Content-Type': contentType},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data ?? const []);
  }
}

class PayjoinNotFoundException extends BullException {
  PayjoinNotFoundException(super.message);
}

class ReceiveCreationException extends BullException {
  ReceiveCreationException(super.message);
}

class NoValidPayjoinBip21Exception extends BullException {
  NoValidPayjoinBip21Exception(super.message);
}

class PayjoinExpiredException extends BullException {
  PayjoinExpiredException(super.message);
}

class OhttpRelaysUnavailableException extends BullException {
  OhttpRelaysUnavailableException(super.message);
}

class SendCreationException extends BullException {
  SendCreationException(super.message);
}

class _IsScriptOwned implements IsScriptOwned {
  final bool Function(Uint8List) _fn;
  _IsScriptOwned(this._fn);

  @override
  bool callback(Uint8List script) => _fn(script);
}

/// Assume the wallet has not seen the inputs since it is an interactive wallet
class _AssumeUnseen implements IsOutputKnown {
  @override
  bool callback(PlainOutPoint outpoint) => false;
}

class _ProcessPsbt implements ProcessPsbt {
  final String Function(String) _sign;
  _ProcessPsbt(this._sign);

  @override
  String callback(String psbt) => _sign(psbt);
}

class InMemoryJsonReceiverSessionPersister
    implements JsonReceiverSessionPersister {
  final List<String> _events;
  bool _closed;

  InMemoryJsonReceiverSessionPersister([List<String>? initial])
    : _events = [...?initial],
      _closed = false;

  factory InMemoryJsonReceiverSessionPersister.fromJson(String? raw) {
    return InMemoryJsonReceiverSessionPersister(_decodeEvents(raw));
  }

  List<String> get events => List.unmodifiable(_events);

  bool get isClosed => _closed;

  String toJson() => jsonEncode(_events);

  @override
  void save(String event) => _events.add(event);

  @override
  List<String> load() => List<String>.from(_events);

  @override
  void close() => _closed = true;
}

class InMemoryJsonSenderSessionPersister implements JsonSenderSessionPersister {
  final List<String> _events;
  bool _closed;

  InMemoryJsonSenderSessionPersister([List<String>? initial])
    : _events = [...?initial],
      _closed = false;

  factory InMemoryJsonSenderSessionPersister.fromJson(String? raw) {
    return InMemoryJsonSenderSessionPersister(_decodeEvents(raw));
  }

  List<String> get events => List.unmodifiable(_events);

  bool get isClosed => _closed;

  String toJson() => jsonEncode(_events);

  @override
  void save(String event) => _events.add(event);

  @override
  List<String> load() => List<String>.from(_events);

  @override
  void close() => _closed = true;
}

List<String> _decodeEvents(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<String>();
    }
  } catch (_) {}
  return const [];
}
