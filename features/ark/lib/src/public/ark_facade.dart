import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/usecases/is_ark_enabled_usecase.dart';
import '../domain/usecases/set_ark_enabled_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';
import '../domain/usecases/create_ark_receive_usecase.dart';

export 'package:ark/ark.dart'
    show
        isArkAddress,
        ArkOperationStatus,
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

/// Published journeys only. Native construction and child derivation belong to
/// the separate setup surface; consumers cannot obtain either from this facade.
final class ArkFacade {
  final EnableArkUsecase _enable;
  final IsArkEnabledUsecase _isEnabled;
  final SetArkEnabledUsecase _setEnabled;
  final ReadArkUsecase _read;
  final SynchronizeArkUsecase _synchronize;
  final QuoteArkOperationUsecase _quote;
  final ConfirmArkOperationUsecase _confirm;
  final CreateArkReceiveUsecase _receive;

  const ArkFacade(
    this._enable,
    this._isEnabled,
    this._setEnabled,
    this._read,
    this._synchronize,
    this._quote,
    this._confirm,
    this._receive,
  );

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
  Future<Result<ArkQuote, ArkFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) => _quote.execute(account, request);
  @useResult
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    ArkQuote quote, {
    required String operationId,
  }) => _confirm.execute(account, quote, operationId);
  @useResult
  Future<Result<ArkReceiveDestination, ArkFailure>> receive(
    ArkAccountId account,
    ArkReceiveRequest request,
  ) => _receive.execute(account, request);
}
