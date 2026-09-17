import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_bloc.freezed.dart';
part 'withdraw_event.dart';
part 'withdraw_state.dart';

class WithdrawBloc extends Bloc<WithdrawEvent, WithdrawState> {
  final LoadWithdrawContextUsecase _loadWithdrawContextUsecase;
  final CreateWithdrawOrderUsecase _createWithdrawOrderUsecase;
  final ConfirmWithdrawOrderUsecase _confirmWithdrawOrderUsecase;

  WithdrawBloc({
    required this._loadWithdrawContextUsecase,
    required this._createWithdrawOrderUsecase,
    required this._confirmWithdrawOrderUsecase,
  }) : super(const WithdrawInitialState()) {
    on<WithdrawStarted>(_onStarted);
    on<WithdrawAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<WithdrawRecipientSelected>(_onRecipientSelected);
    on<WithdrawInteracSecurityDetailsSubmitted>(
      _onInteracSecurityDetailsSubmitted,
      transformer: droppable(),
    );
    on<WithdrawConfirmed>(_onConfirmed);
  }

  Future<void> _onStarted(
    WithdrawStarted event,
    Emitter<WithdrawState> emit,
  ) async {
    // Reset the initial state to clear any previous failure
    final initialState = switch (state) {
      final WithdrawInitialState initial => initial,
      _ => const WithdrawInitialState(),
    };
    emit(initialState.copyWith(failure: null));

    switch (await _loadWithdrawContextUsecase.userSummary()) {
      case Ok(:final value):
        emit(initialState.toAmountInputState(userSummary: value));
      case Err(:final failure):
        emit(WithdrawState.initial(failure: failure));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    WithdrawAmountInputContinuePressed event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a clean WithdrawAmountInputState here
    final amountInputState = state.cleanAmountInputState;
    if (amountInputState == null) {
      log.severe(
        error: 'Expected to be on WithdrawAmountInputState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(amountInputState);

    final amount = FiatAmount(double.parse(event.amountInput));

    emit(
      amountInputState.toRecipientInputState(
        amount: amount,
        currency: event.fiatCurrency,
      ),
    );
  }

  Future<void> _onRecipientSelected(
    WithdrawRecipientSelected event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawRecipientInputState here
    final recipientInputState = state.cleanRecipientInputState;
    if (recipientInputState == null) {
      log.severe(
        error: 'Expected to be on WithdrawRecipientInputState',
        trace: StackTrace.current,
      );
      return;
    }
    if (state is! WithdrawRecipientInputState) {
      emit(recipientInputState);
    }

    final recipient = event.recipient;
    if (recipient.requiresInteracSecurityDetails) {
      emit(
        recipientInputState.toPaymentDetailsInputState(recipient: recipient),
      );
      return;
    }

    emit(recipientInputState.copyWith(isCreatingWithdrawOrder: true));

    try {
      switch (await _createWithdrawOrderUsecase.execute(
        fiatAmount: recipientInputState.amount.amount,
        recipientId: recipient.id,
      )) {
        case Ok(:final value):
          emit(
            recipientInputState.toConfirmationState(
              recipient: recipient,
              order: value.order,
            ),
          );
        case Err(:final failure):
          emit(
            event.isNew
                ? recipientInputState.copyWith(
                    isCreatingWithdrawOrder: false,
                    newRecipientFailure: failure,
                  )
                : recipientInputState.copyWith(
                    isCreatingWithdrawOrder: false,
                    selectedRecipientFailure: failure,
                  ),
          );
      }
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while creating the withdrawal order',
        error: e,
        trace: st,
      );
      final failure = WithdrawUnexpectedFailure(
        'create threw: ${e.runtimeType}',
      );
      emit(
        event.isNew
            ? recipientInputState.copyWith(
                isCreatingWithdrawOrder: false,
                newRecipientFailure: failure,
              )
            : recipientInputState.copyWith(
                isCreatingWithdrawOrder: false,
                selectedRecipientFailure: failure,
              ),
      );
    }
  }

  Future<void> _onInteracSecurityDetailsSubmitted(
    WithdrawInteracSecurityDetailsSubmitted event,
    Emitter<WithdrawState> emit,
  ) async {
    final currentState = state;
    if (currentState case WithdrawPaymentDetailsInputState(
      isCreatingWithdrawOrder: true,
    )) {
      return;
    }
    final securityDetailsState = currentState.cleanPaymentDetailsInputState;
    if (securityDetailsState == null) {
      log.severe(
        error: 'Expected payment details or confirmation state',
        trace: StackTrace.current,
      );
      return;
    }

    emit(
      securityDetailsState.copyWith(
        isCreatingWithdrawOrder: true,
        failure: null,
      ),
    );

    final recipient = securityDetailsState.recipient;
    try {
      switch (await _createWithdrawOrderUsecase.execute(
        fiatAmount: securityDetailsState.amount.amount,
        recipientId: recipient.id,
        recipientEmail: recipient.email,
        securityQuestion: event.securityQuestion,
        securityAnswer: event.securityAnswer,
      )) {
        case Ok(
          value: CreateWithdrawOrderResult(
            :final order,
            interacSecurityDetails: final InteracSecurityDetails details,
          ),
        ):
          emit(
            securityDetailsState.toConfirmationState(
              order: order,
              interacSecurityDetails: details,
              saveSecurityDetailsAsDefault: event.saveAsDefault,
            ),
          );
        case Ok():
          // The use-case returns details whenever the recipient has an
          // email, so this is a broken contract, not a user-facing condition.
          log.severe(
            error: 'Missing Interac security details',
            trace: StackTrace.current,
          );
          emit(
            securityDetailsState.copyWith(
              failure: const WithdrawUnexpectedFailure(
                'Missing Interac security details',
              ),
            ),
          );
        case Err(:final failure):
          emit(securityDetailsState.copyWith(failure: failure));
      }
    } catch (e, st) {
      // Only the type is logged: the submission carries the Interac security
      // answer, which must never reach diagnostics.
      log.severe(
        message: 'Unexpected error while creating the withdrawal order',
        error: 'create threw: ${e.runtimeType}',
        trace: st,
      );
      emit(
        securityDetailsState.copyWith(
          failure: WithdrawUnexpectedFailure('create threw: ${e.runtimeType}'),
        ),
      );
    }
  }

  Future<void> _onConfirmed(
    WithdrawConfirmed event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawConfirmationState here
    final confirmationState = state.cleanConfirmationState;
    if (confirmationState == null) {
      log.severe(
        error: 'Expected to be on WithdrawConfirmationState',
        trace: StackTrace.current,
      );
      return;
    }
    emit(
      confirmationState.copyWith(isConfirmingWithdrawal: true, failure: null),
    );

    try {
      switch (await _confirmWithdrawOrderUsecase.execute(
        orderId: confirmationState.order.orderId,
        interacSecurityDetails: confirmationState.interacSecurityDetails,
        saveSecurityDetailsAsDefault:
            confirmationState.saveSecurityDetailsAsDefault,
      )) {
        case Ok(:final value):
          emit(confirmationState.toSuccessState(order: value));
        case Err(:final failure):
          emit(
            confirmationState.copyWith(
              isConfirmingWithdrawal: false,
              failure: failure,
            ),
          );
      }
    } catch (e, st) {
      log.severe(
        message: 'Unexpected error while confirming the withdrawal',
        error: e,
        trace: st,
      );
      emit(
        confirmationState.copyWith(
          isConfirmingWithdrawal: false,
          failure: WithdrawUnexpectedFailure('confirm threw: ${e.runtimeType}'),
        ),
      );
    }
  }
}
