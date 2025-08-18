import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_recipients_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_bloc.freezed.dart';
part 'withdraw_event.dart';
part 'withdraw_state.dart';

class WithdrawBloc extends Bloc<WithdrawEvent, WithdrawState> {
  WithdrawBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required ListRecipientsUsecase listRecipientsUsecase,
    required CreateWithdrawOrderUsecase createWithdrawUsecase,
    required ConfirmWithdrawOrderUsecase confirmWithdrawUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _listRecipientsUsecase = listRecipientsUsecase,
       _createWithdrawOrderUsecase = createWithdrawUsecase,
       _confirmWithdrawUsecase = confirmWithdrawUsecase,
       super(const WithdrawInitialState()) {
    on<WithdrawStarted>(_onStarted);
    on<WithdrawAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<WithdrawNewRecipientAdded>(_onNewRecipientAdded);
    on<WithdrawRecipientSelected>(_onRecipientSelected);
    /*on<WithdrawDescriptionInputContinuePressed>(
      _onDescriptionInputContinuePressed,
    );*/
    on<WithdrawConfirmed>(_onConfirmed);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ListRecipientsUsecase _listRecipientsUsecase;
  final CreateWithdrawOrderUsecase _createWithdrawOrderUsecase;
  final ConfirmWithdrawOrderUsecase _confirmWithdrawUsecase;

  Future<void> _onStarted(
    WithdrawStarted event,
    Emitter<WithdrawState> emit,
  ) async {
    try {
      // Reset the initial state to clear any previous exceptions
      WithdrawInitialState initialState;
      if (state is WithdrawInitialState) {
        initialState = state as WithdrawInitialState;
      } else {
        initialState = const WithdrawInitialState();
      }
      emit(
        initialState.copyWith(
          apiKeyException: null,
          getUserSummaryException: null,
          listRecipientsException: null,
        ),
      );

      final (userSummary, recipients) =
          await (
            _getExchangeUserSummaryUsecase.execute(),
            _listRecipientsUsecase.execute(fiatOnly: true),
          ).wait;

      emit(
        initialState.toAmountInputState(
          userSummary: userSummary,
          recipients: recipients,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(WithdrawState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(WithdrawState.initial(getUserSummaryException: e));
    } on ListRecipientsException catch (e) {
      emit(WithdrawState.initial(listRecipientsException: e));
    }
  }

  Future<void> _onAmountInputContinuePressed(
    WithdrawAmountInputContinuePressed event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawAmountInputState or WithdrawRecipientInputState and
    //  return to a clean WithdrawAmountInputState state to change the amount
    WithdrawAmountInputState amountInputState;
    switch (state) {
      case WithdrawAmountInputState _:
        amountInputState = state as WithdrawAmountInputState;
      case final WithdrawRecipientInputState recipientInputState:
        amountInputState = recipientInputState.toAmountInputState();
      default:
        // Unexpected state, do nothing
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

  Future<void> _onNewRecipientAdded(
    WithdrawNewRecipientAdded event,
    Emitter<WithdrawState> emit,
  ) async {
    // TODO
  }

  Future<void> _onRecipientSelected(
    WithdrawRecipientSelected event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawRecipientInputState or WithdrawAmountInputState and
    //  return to a clean WithdrawRecipientInputState to change the recipient
    WithdrawRecipientInputState recipientInputState;
    switch (state) {
      case WithdrawRecipientInputState _:
        recipientInputState = state as WithdrawRecipientInputState;
      case final WithdrawConfirmationState confirmationState:
        recipientInputState = confirmationState.toRecipientInputState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(
      recipientInputState.copyWith(error: null, isCreatingWithdrawOrder: true),
    );

    try {
      final recipient = event.recipient;
      // TODO: GET CORRECT PAYMENT PROCESSORS
      // ignore: unused_local_variable
      final recipientTypeFiat = recipient.recipientType;
      final order = await _createWithdrawOrderUsecase.execute(
        fiatAmount: recipientInputState.amount.amount,
        recipientId: recipient.recipientId,
        paymentProcessor: recipientTypeFiat.value,
      );
      emit(
        recipientInputState.toConfirmationState(
          recipient: recipient,
          order: order,
        ),
      );
    } on WithdrawError catch (e) {
      emit(recipientInputState.copyWith(error: e));
    } catch (e) {
      log.severe('Error in WithdrawBloc: $e');
      emit(
        recipientInputState.copyWith(
          error: WithdrawError.unexpected(message: '$e'),
        ),
      );
    } finally {
      // Reset the isCreatingWithdrawOrder flag if any error occured
      if (state is WithdrawRecipientInputState) {
        emit(
          (state as WithdrawRecipientInputState).copyWith(
            isCreatingWithdrawOrder: false,
          ),
        );
      }
    }
  }

  /*Future<void> _onDescriptionInputContinuePressed(
    WithdrawDescriptionInputContinuePressed event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawDescriptionInputState or WithdrawConfirmationState and
    //  return to a clean WithdrawDescriptionInputState state to change the description
    WithdrawDescriptionInputState descriptionInputState;
    switch (state) {
      case WithdrawDescriptionInputState _:
        descriptionInputState = state as WithdrawDescriptionInputState;
      case final WithdrawConfirmationState confirmationState:
        descriptionInputState = confirmationState.toDescriptionInputState();
      default:
        // Unexpected state, do nothing
        return;
    }
    emit(
      descriptionInputState.copyWith(
        error: null,
        isCreatingWithdrawOrder: true,
      ),
    );

    try {
      final order = await _createWithdrawOrderUsecase.execute(
        fiatAmount: descriptionInputState.fiatOrderAmount.amount,
        recipientId: descriptionInputState.recipient.recipientId,
      );
      emit(descriptionInputState.toConfirmationState(order: order));
    } on WithdrawError catch (e) {
      emit(descriptionInputState.copyWith(error: e));
    } finally {
      // Reset the isCreatingWithdrawOrder flag if any error occured
      if (state is WithdrawDescriptionInputState) {
        emit(
          (state as WithdrawDescriptionInputState).copyWith(
            isCreatingWithdrawOrder: false,
          ),
        );
      }
    }
  }*/

  Future<void> _onConfirmed(
    WithdrawConfirmed event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawConfirmationState and
    //  return to a clean WithdrawConfirmationState state to confirm the withdraw
    WithdrawConfirmationState confirmationState;
    if (state is WithdrawConfirmationState) {
      confirmationState = state as WithdrawConfirmationState;
    } else {
      // Unexpected state, do nothing
      return;
    }
    emit(confirmationState.copyWith(isConfirmingWithdrawal: true, error: null));

    try {
      final order = await _confirmWithdrawUsecase.execute(
        orderId: confirmationState.order.orderId,
      );
      emit(confirmationState.toInProgressState(order: order));
    } on WithdrawError catch (e) {
      emit(confirmationState.copyWith(error: e));
    } finally {
      // Reset the isConfirmingWithdraw flag if any error occured
      if (state is WithdrawConfirmationState) {
        emit(
          (state as WithdrawConfirmationState).copyWith(
            isConfirmingWithdrawal: false,
          ),
        );
      }
    }
  }
}
