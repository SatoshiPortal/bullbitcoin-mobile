import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'withdraw_bloc.freezed.dart';
part 'withdraw_event.dart';
part 'withdraw_state.dart';

class WithdrawBloc extends Bloc<WithdrawEvent, WithdrawState> {
  WithdrawBloc({
    required this._loadWithdrawContextUsecase,
    required this._createWithdrawOrderUsecase,
    required this._confirmWithdrawOrderUsecase,
  }) : super(const WithdrawInitialState()) {
    on<WithdrawStarted>(_onStarted);
    on<WithdrawAmountInputContinuePressed>(_onAmountInputContinuePressed);
    on<WithdrawRecipientSelected>(_onRecipientSelected);
    on<WithdrawConfirmed>(_onConfirmed);
  }

  final LoadWithdrawContextUsecase _loadWithdrawContextUsecase;
  final CreateWithdrawOrderUsecase _createWithdrawOrderUsecase;
  final ConfirmWithdrawOrderUsecase _confirmWithdrawOrderUsecase;

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
    emit(recipientInputState.copyWith(isCreatingWithdrawOrder: true));

    final recipient = event.recipient;

    switch (await _createWithdrawOrderUsecase.execute(
      fiatAmount: recipientInputState.amount.amount,
      recipientId: recipient.id,
      recipientType: recipient.type,
    )) {
      case Ok(:final value):
        emit(
          recipientInputState.toConfirmationState(
            recipient: recipient,
            order: value,
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

    switch (await _confirmWithdrawOrderUsecase.execute(
      orderId: confirmationState.order.orderId,
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
  }
}
