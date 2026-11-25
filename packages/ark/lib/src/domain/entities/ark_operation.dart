import 'package:primitives/primitives.dart';

import 'ark_quote.dart';

enum ArkOperationStatus {
  prepared,
  admitted,
  pending,
  succeeded,
  failed,
  outcomeUnknown,
  conflicted,
}

sealed class ArkSubmission {
  const ArkSubmission();
  factory ArkSubmission.rebroadcastClaim({
    required String operationId,
    required String expectedTxid,
  }) = ArkRebroadcastClaim;
  factory ArkSubmission.confirmQuote({
    required String quoteId,
    required String operationId,
  }) = ArkConfirmQuote;
  factory ArkSubmission.boardFunding({
    required String operationId,
    required String quoteId,
  }) = ArkBoardFunding;
  factory ArkSubmission.registerBoard({
    required String operationId,
    required String unfinalisedPsbt,
    required int? keypairIndex,
    required int expiryHeight,
  }) = ArkRegisterBoard;
}

final class ArkRebroadcastClaim extends ArkSubmission {
  final String operationId;
  final String expectedTxid;
  ArkRebroadcastClaim({required this.operationId, required this.expectedTxid}) {
    if (operationId.isEmpty ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedTxid)) {
      throw ArgumentError('Invalid claim recovery identity');
    }
  }
}

final class ArkClaimRecovery {
  final String txid;
  final String destination;
  final Sats net;
  final Sats fee;
  ArkClaimRecovery({
    required this.txid,
    required this.destination,
    required this.net,
    required this.fee,
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(txid) || destination.isEmpty) {
      throw ArgumentError('Invalid signed claim summary');
    }
  }
}

final class ArkConfirmQuote extends ArkSubmission {
  final String quoteId;
  final String operationId;
  ArkConfirmQuote({required this.quoteId, required this.operationId}) {
    if (quoteId.isEmpty || operationId.isEmpty) {
      throw ArgumentError('Missing operation identity');
    }
  }
}

final class ArkBoardFunding extends ArkSubmission {
  final String operationId;
  final String quoteId;
  ArkBoardFunding({required this.operationId, required this.quoteId}) {
    if (operationId.isEmpty) throw ArgumentError('Missing operation identity');
  }
}

final class ArkRegisterBoard extends ArkSubmission {
  final String operationId;
  final String unfinalisedPsbt;
  final int? keypairIndex;
  final int expiryHeight;
  ArkRegisterBoard({
    required this.operationId,
    required this.unfinalisedPsbt,
    required int? keypairIndex,
    required this.expiryHeight,
  }) : keypairIndex = keypairIndex {
    if (operationId.isEmpty ||
        unfinalisedPsbt.isEmpty ||
        (keypairIndex != null && keypairIndex < 0) ||
        expiryHeight < 0) {
      throw ArgumentError('Invalid board registration');
    }
  }
}

final class ArkBoardFundingDetails {
  final String address;
  final int? keypairIndex;
  final String? scuttleToken;
  final int expiryHeight;
  ArkBoardFundingDetails({
    required this.address,
    required int keypairIndex,
    required this.expiryHeight,
  }) : keypairIndex = keypairIndex,
       scuttleToken = null {
    if (address.isEmpty || keypairIndex < 0 || expiryHeight < 0) {
      throw ArgumentError('Invalid board funding tuple');
    }
  }

  ArkBoardFundingDetails.scuttle({
    required this.address,
    required String token,
    required this.expiryHeight,
  }) : keypairIndex = null,
       scuttleToken = token {
    if (address.isEmpty || token.isEmpty || expiryHeight < 0) {
      throw ArgumentError('Invalid Scuttle board funding tuple');
    }
  }
}

final class ArkOperation {
  final String id;
  final ArkOperationKind kind;
  final ArkOperationStatus status;
  final Uri chainSource;
  final int configGeneration;
  final String? nativeReference;
  final List<String> actualIds;
  final List<String> skippedIds;
  final ArkBoardFundingDetails? boardFunding;
  final ArkClaimRecovery? claimRecovery;
  ArkOperation({
    required this.id,
    required this.kind,
    required this.status,
    required this.chainSource,
    required this.configGeneration,
    this.nativeReference,
    List<String> actualIds = const [],
    List<String> skippedIds = const [],
    this.boardFunding,
    this.claimRecovery,
  }) : actualIds = List.unmodifiable(actualIds),
       skippedIds = List.unmodifiable(skippedIds) {
    if (id.isEmpty) throw ArgumentError('Missing operation identity');
  }
}
