import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/ark_claim_recovery_selection.dart';
import '../domain/usecases/review_ark_claim_recovery_usecase.dart';
import '../domain/usecases/rebroadcast_ark_claim_usecase.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/usecases/is_ark_enabled_usecase.dart';
import '../domain/usecases/list_enabled_ark_accounts_usecase.dart';
import '../domain/usecases/set_ark_enabled_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';
import '../domain/usecases/create_ark_receive_usecase.dart';
import '../domain/ark_board_preparation.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
import '../domain/usecases/read_ark_board_usecase.dart';
import '../domain/usecases/confirm_ark_board_usecase.dart';

export 'package:ark/ark.dart'
    show
        isArkAddress,
        ArkOperationStatus,
        ArkRebroadcastClaim,
        ArkClaimRecovery,
        ArkSubmission,
        ArkConfirmQuote,
        ArkBoardFunding,
        ArkRegisterBoard,
        ArkBoardFundingDetails,
        ArkOperation,
        ArkBackend,
        ArkAccountId,
        ArkAccountConfig,
        ArkVtxoState,
        ArkRecoveryStatus,
        ArkRenewalStatus,
        ArkExitStatus,
        ArkObligationStatus,
        ArkVtxo,
        ArkMovement,
        ArkServerInfo,
        ArkSnapshot,
        ArkPassOutcome,
        ArkStage,
        ArkSectionCompleteness,
        ArkExit,
        ArkPendingBoard,
        ArkMovementKind,
        ArkMovementStatus,
        ArkReceiveRequest,
        ArkAddressReceiveRequest,
        ArkBolt11ReceiveRequest,
        ArkReceiveDestination,
        ArkOperationKind,
        ArkDestinationKind,
        ArkPaymentDestination,
        ArkQuoteRequest,
        ArkPaymentQuoteRequest,
        ArkRenewalQuoteRequest,
        ArkEmergencyExitQuoteRequest,
        ArkExitProgressQuoteRequest,
        ArkClaimQuoteRequest,
        ArkBoardQuoteRequest,
        ArkQuote;

export '../domain/ark_failure.dart';
export '../domain/ark_board_preparation.dart';

/// Only this feature issues a Board review, from a trusted host journal read.
final class ArkBoardReview {
  final ArkBoardPreparation _preparation;
  const ArkBoardReview._(this._preparation);
  ArkBoardPreparation get details => _preparation;
}

/// Issued only by ArkFacade.quote. Display metadata conveys no construction
/// authority: confirmation always uses the original immutable package quote.
final class ArkReview {
  final ArkQuote _quote;
  const ArkReview._(this._quote);
  ArkQuote get details => _quote;
}

/// Bound to the exact saved account/operation/transaction by a trusted read.
/// Display getters cannot construct or change the recovery command.
final class ArkClaimRecoveryReview {
  final ArkClaimRecoverySelection _selection;
  const ArkClaimRecoveryReview._(this._selection);
  ArkAccountId get account => _selection.account;
  String get operationId => _selection.operation.id;
  ArkClaimRecovery get details => _selection.summary;
  ArkOperationStatus get status => _selection.operation.status;
  List<String> get actualIds => _selection.operation.actualIds;
  List<String> get skippedIds => _selection.operation.skippedIds;
}

/// Published journeys only. Native construction and child derivation belong to
/// the separate setup surface; consumers cannot obtain either from this facade.
final class ArkFacade {
  final EnableArkUsecase _enable;
  final ReviewArkClaimRecoveryUsecase? _reviewClaimRecovery;
  final RebroadcastArkClaimUsecase? _rebroadcastClaim;
  final ListEnabledArkAccountsUsecase? _accounts;
  final IsArkEnabledUsecase _isEnabled;
  final SetArkEnabledUsecase _setEnabled;
  final ReadArkUsecase _read;
  final SynchronizeArkUsecase _synchronize;
  final QuoteArkOperationUsecase _quote;
  final ConfirmArkOperationUsecase _confirm;
  final CreateArkReceiveUsecase _receive;
  final PrepareArkBoardUsecase _prepareBoard;
  final ReadArkBoardUsecase _readBoard;
  final ConfirmArkBoardUsecase _confirmBoard;

  const ArkFacade(
    this._enable,
    this._isEnabled,
    this._setEnabled,
    this._read,
    this._synchronize,
    this._quote,
    this._confirm,
    this._receive,
    this._prepareBoard,
    this._readBoard,
    this._confirmBoard, [
    this._accounts,
    this._reviewClaimRecovery,
    this._rebroadcastClaim,
  ]);

  @useResult
  Future<Result<ArkBoardPreparation, ArkFailure>> prepareBoard(
    ArkAccountConfig config,
    Sats amount,
  ) => _prepareBoard.execute(config, amount);

  @useResult
  Future<Result<ArkBoardReview, ArkFailure>> reviewBoard(
    ArkAccountId account,
    String operationId,
  ) async =>
      (await _readBoard.execute(account, operationId)).map(ArkBoardReview._);

  @useResult
  Future<Result<ArkOperation, ArkFailure>> confirmBoard(
    ArkAccountId account,
    ArkBoardReview review,
  ) => _confirmBoard.execute(account, review._preparation);

  @useResult
  Future<Result<List<ArkAccountId>, ArkFailure>> listEnabledAccounts(
    BitcoinNetwork network,
  ) =>
      _accounts?.execute(network) ??
      Future.value(const Err(ArkServiceUnavailableFailure()));

  @useResult
  Future<Result<ArkClaimRecoveryReview, ArkFailure>> reviewClaimRecovery(
    ArkAccountId account,
    String operationId,
  ) async {
    final review = _reviewClaimRecovery;
    if (review == null) return const Err(ArkServiceUnavailableFailure());
    return (await review.execute(
      account,
      operationId,
    )).map(ArkClaimRecoveryReview._);
  }

  @useResult
  Future<Result<ArkOperation, ArkFailure>> rebroadcastClaim(
    ArkAccountId account,
    ArkClaimRecoveryReview review,
  ) =>
      _rebroadcastClaim?.execute(account, review._selection) ??
      Future.value(const Err(ArkServiceUnavailableFailure()));

  @useResult
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) =>
      _isEnabled.execute(account);

  @useResult
  Future<Result<ArkSnapshot, ArkFailure>> enable(
    ArkAccountConfig config, {
    required bool privacyDisclosureAccepted,
  }) => _enable.execute(
    config,
    privacyDisclosureAccepted: privacyDisclosureAccepted,
  );
  @useResult
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) => _setEnabled.execute(account, enabled);
  @useResult
  Future<Result<ArkSnapshot, ArkFailure>> read(ArkAccountId account) =>
      _read.execute(account);
  Stream<Result<ArkSnapshot, ArkFailure>> watch(ArkAccountId account) =>
      _read.watch(account);
  @useResult
  Future<Result<ArkPassOutcome, ArkFailure>> synchronize(
    ArkAccountId account, {
    required bool renew,
  }) => _synchronize.execute(account, renew: renew);
  @useResult
  Future<Result<ArkReview, ArkFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) async => (await _quote.execute(account, request)).map(ArkReview._);
  @useResult
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    ArkReview review, {
    required String operationId,
  }) => _confirm.execute(account, review._quote, operationId);
  @useResult
  Future<Result<ArkReceiveDestination, ArkFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) => _receive.execute(account, request);
}
