import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/errors/withdraw_error.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_virtual_iban_details_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_from_viban_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_bloc.freezed.dart';
part 'withdraw_event.dart';
part 'withdraw_state.dart';

class WithdrawBloc extends Bloc<WithdrawEvent, WithdrawState> {
  WithdrawBloc({
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required GetVirtualIbanDetailsUsecase getVirtualIbanDetailsUsecase,
    required CreateWithdrawOrderUsecase createWithdrawUsecase,
    required CreateWithdrawOrderFromVibanUsecase
        createWithdrawOrderFromVibanUsecase,
    required ConfirmWithdrawOrderUsecase confirmWithdrawUsecase,
  })  : _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
        _getVirtualIbanDetailsUsecase = getVirtualIbanDetailsUsecase,
        _createWithdrawOrderUsecase = createWithdrawUsecase,
        _createWithdrawOrderFromVibanUsecase =
            createWithdrawOrderFromVibanUsecase,
        _confirmWithdrawUsecase = confirmWithdrawUsecase,
        super(const WithdrawInitialState()) {
    on<WithdrawStarted>(_onStarted);
    on<WithdrawAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<WithdrawRecipientSelected>(_onRecipientSelected);
    on<WithdrawUseVirtualIbanToggled>(_onUseVirtualIbanToggled);
    /*on<WithdrawDescriptionInputContinuePressed>(
      _onDescriptionInputContinuePressed,
    );*/
    on<WithdrawConfirmed>(_onConfirmed);
  }

  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;
  final GetVirtualIbanDetailsUsecase _getVirtualIbanDetailsUsecase;
  final CreateWithdrawOrderUsecase _createWithdrawOrderUsecase;
  final CreateWithdrawOrderFromVibanUsecase _createWithdrawOrderFromVibanUsecase;
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
        ),
      );

      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      // Check if user has an active Virtual IBAN (for EUR withdrawals)
      VirtualIbanRecipient? virtualIban;
      try {
        virtualIban = await _getVirtualIbanDetailsUsecase.execute();
      } catch (e) {
        // Silently ignore errors when checking for Virtual IBAN
        // User might not have one or it might not be available
        log.info('Could not fetch Virtual IBAN details: $e');
      }

      final hasActiveVirtualIban = virtualIban?.isActive ?? false;

      emit(
        WithdrawAmountInputState(
          userSummary: userSummary,
          hasActiveVirtualIban: hasActiveVirtualIban,
          // Default to using Virtual IBAN if user has an active one
          useVirtualIban: hasActiveVirtualIban,
        ),
      );
    } on ApiKeyException catch (e) {
      emit(WithdrawState.initial(apiKeyException: e));
    } on GetExchangeUserSummaryException catch (e) {
      emit(WithdrawState.initial(getUserSummaryException: e));
    }
  }

  void _onUseVirtualIbanToggled(
    WithdrawUseVirtualIbanToggled event,
    Emitter<WithdrawState> emit,
  ) {
    final currentState = state;
    if (currentState is WithdrawAmountInputState) {
      emit(currentState.copyWith(useVirtualIban: event.useVirtualIban));
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
      final useVirtualIban = recipientInputState.useVirtualIban;
      final isEurCurrency = recipientInputState.currency.code == 'EUR';

      WithdrawOrder order;

      // Use Virtual IBAN withdrawal for EUR when:
      // 1. useVirtualIban is enabled AND currency is EUR, OR
      // 2. The recipient is already FR_PAYEE type
      if ((useVirtualIban && isEurCurrency) ||
          recipient.type == RecipientType.frPayee) {
        order = await _createWithdrawOrderFromVibanUsecase.execute(
          recipient: recipient,
          fiatAmount: recipientInputState.amount.amount,
        );
      } else {
        // Regular withdrawal process
        order = await _createWithdrawOrderUsecase.execute(
          fiatAmount: recipientInputState.amount.amount,
          recipientId: recipient.id,
          recipientType: recipient.type,
        );
      }

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
}
