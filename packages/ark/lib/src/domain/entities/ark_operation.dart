import 'ark_quote.dart';

enum ArkOperationStatus {
  prepared,
  admitted,
  pending,
  succeeded,
  failed,
  outcomeUnknown,
}

sealed class ArkSubmission {
  const ArkSubmission();
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
    required int keypairIndex,
    required int expiryHeight,
  }) = ArkRegisterBoard;
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
  final int keypairIndex;
  final int expiryHeight;
  ArkRegisterBoard({
    required this.operationId,
    required this.unfinalisedPsbt,
    required this.keypairIndex,
    required this.expiryHeight,
  }) {
    if (operationId.isEmpty ||
        unfinalisedPsbt.isEmpty ||
        keypairIndex < 0 ||
        expiryHeight < 0) {
      throw ArgumentError('Invalid board registration');
    }
  }
}

final class ArkBoardFundingDetails {
  final String address;
  final int keypairIndex;
  final int expiryHeight;
  ArkBoardFundingDetails({
    required this.address,
    required this.keypairIndex,
    required this.expiryHeight,
  }) {
    if (address.isEmpty || keypairIndex < 0 || expiryHeight < 0) {
      throw ArgumentError('Invalid board funding tuple');
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
  }) : actualIds = List.unmodifiable(actualIds),
       skippedIds = List.unmodifiable(skippedIds) {
    if (id.isEmpty) throw ArgumentError('Missing operation identity');
  }
}
