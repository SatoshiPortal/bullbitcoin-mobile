import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/entity/new_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/recipient.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_fiat_recipient_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/list_cad_billers_usecase.dart';
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
    required CreateFiatRecipientUsecase createFiatRecipientUsecase,
    required ListCadBillersUsecase listCadBillersUsecase,
  }) : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       _listRecipientsUsecase = listRecipientsUsecase,
       _createWithdrawOrderUsecase = createWithdrawUsecase,
       _confirmWithdrawUsecase = confirmWithdrawUsecase,
       _createFiatRecipientUsecase = createFiatRecipientUsecase,
       _listCadBillersUsecase = listCadBillersUsecase,
       super(const WithdrawInitialState()) {
    on<WithdrawStarted>(_onStarted);
    on<WithdrawAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<WithdrawNewRecipientAdded>(_onNewRecipientAdded);
    on<WithdrawCreateNewRecipient>(_onCreateNewRecipient);
    on<WithdrawRecipientSelected>(_onRecipientSelected);
    on<WithdrawGetCadBillers>(_onGetCadBillers);
    /*on<WithdrawDescriptionInputContinuePressed>(
      _onDescriptionInputContinuePressed,
    );*/
    on<WithdrawConfirmed>(_onConfirmed);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final ListRecipientsUsecase _listRecipientsUsecase;
  final CreateWithdrawOrderUsecase _createWithdrawOrderUsecase;
  final ConfirmWithdrawOrderUsecase _confirmWithdrawUsecase;
  final CreateFiatRecipientUsecase _createFiatRecipientUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;

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
    // We should be on a clean WithdrawAmountInputState here
    final amountInputState = state.cleanAmountInputState;
    if (amountInputState == null) {
      log.severe('Expected to be on WithdrawAmountInputState but on: $state');
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

  Future<void> _onCreateNewRecipient(
    WithdrawCreateNewRecipient event,
    Emitter<WithdrawState> emit,
  ) async {
    if (state is WithdrawRecipientInputState) {
      final currentState = state as WithdrawRecipientInputState;

      // Set loading state for new recipient creation
      emit(currentState.copyWith(isCreatingNewRecipient: true));

      // Use the recipient from the event directly
      final newRecipient = event.newRecipient;
      try {
        final createdRecipient = await _createFiatRecipientUsecase.execute(
          newRecipient,
        );

        // Add the new recipient to the list and update state
        final updatedRecipients = [
          ...currentState.recipients,
          createdRecipient,
        ];

        // Update state with the new recipient list and clear the newRecipient
        // Keep isCreatingNewRecipient true for the order creation phase
        final updatedState = currentState.copyWith(
          recipients: updatedRecipients,
          newRecipient: null,
          isCreatingNewRecipient: true,
        );
        emit(updatedState);

        // Now create the withdrawal order using the newly created recipient
        final order = await _createWithdrawOrderUsecase.execute(
          fiatAmount: currentState.amount.amount,
          recipientId: createdRecipient.recipientId,
          recipientType: createdRecipient.recipientType,
        );

        // Transition to confirmation state
        emit(
          updatedState.toConfirmationState(
            recipient: createdRecipient,
            order: order,
          ),
        );
      } catch (e) {
        log.severe('Error creating new recipient: $e');
        emit(
          currentState.copyWith(
            error: WithdrawError.unexpected(
              message: 'Failed to create recipient: $e',
            ),
            isCreatingNewRecipient: false, // Reset loading state on error
          ),
        );
      }
    }
  }

  Future<void> _onRecipientSelected(
    WithdrawRecipientSelected event,
    Emitter<WithdrawState> emit,
  ) async {
    // We should be on a WithdrawRecipientInputState here
    final recipientInputState = state.cleanRecipientInputState;
    if (recipientInputState == null) {
      log.severe(
        'Expected to be on WithdrawRecipientInputState but on: $state',
      );
      return;
    }
    emit(recipientInputState.copyWith(isCreatingWithdrawOrder: true));

    try {
      final recipient = event.recipient;

      final order = await _createWithdrawOrderUsecase.execute(
        fiatAmount: recipientInputState.amount.amount,
        recipientId: recipient.recipientId,
        recipientType: recipient.recipientType,
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
    // We should be on a WithdrawConfirmationState here
    final confirmationState = state.cleanConfirmationState;
    if (confirmationState == null) {
      log.severe('Expected to be on WithdrawConfirmationState but on: $state');
      return;
    }
    emit(confirmationState.copyWith(isConfirmingWithdrawal: true, error: null));

    try {
      final order = await _confirmWithdrawUsecase.execute(
        orderId: confirmationState.order.orderId,
      );
      emit(confirmationState.toSuccessState(order: order));
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

  Future<void> _onGetCadBillers(
    WithdrawGetCadBillers event,
    Emitter<WithdrawState> emit,
  ) async {
    if (state is WithdrawRecipientInputState) {
      final currentState = state as WithdrawRecipientInputState;

      // Only search if search term has at least 3 characters
      if (event.searchTerm.length < 3) {
        return;
      }

      emit(currentState.copyWith(isLoadingCadBillers: true));

      try {
        final cadBillers = await _listCadBillersUsecase.execute(
          searchTerm: event.searchTerm,
        );
        emit(
          currentState.copyWith(
            cadBillers: cadBillers,
            isLoadingCadBillers: false,
          ),
        );
      } catch (e) {
        log.severe('Error fetching CAD billers: $e');
        emit(
          currentState.copyWith(
            isLoadingCadBillers: false,
            error: WithdrawError.unexpected(
              message: 'Failed to load billers: $e',
            ),
          ),
        );
      }
    }
  }
}
