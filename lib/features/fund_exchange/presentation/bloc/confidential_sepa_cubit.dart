import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/get_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/watch_virtual_iban_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_presentation_error.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart'
    show RecipientsFailure, VirtualIban, VirtualIbanStatus;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'confidential_sepa_cubit.freezed.dart';
part 'confidential_sepa_state.dart';

class ConfidentialSepaCubit extends Cubit<ConfidentialSepaState> {
  final WatchVirtualIbanUsecase _watchVirtualIbanUsecase;
  StreamSubscription<Result<VirtualIban, RecipientsFailure>>? _subscription;

  ConfidentialSepaCubit(this._watchVirtualIbanUsecase)
    : super(const ConfidentialSepaState());

  Future<void> load() => _watch(createIfAbsent: false);

  Future<void> activate() => _watch(createIfAbsent: true);

  void confirmationChanged(bool value) {
    emit(state.copyWith(isNameConfirmed: value));
  }

  Future<void> _watch({required bool createIfAbsent}) async {
    if (isClosed) return;
    await _subscription?.cancel();
    emit(
      state.copyWith(isLoading: true, isCreating: createIfAbsent, error: null),
    );
    _subscription = _watchVirtualIbanUsecase
        .execute(createIfAbsent: createIfAbsent)
        .listen(_onResult, onDone: _onDone);
  }

  void _onResult(Result<VirtualIban, RecipientsFailure> result) {
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: value.status,
            isLoading: value.status == VirtualIbanStatus.pending,
            isCreating: value.status == VirtualIbanStatus.pending,
            error: null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            isLoading: false,
            isCreating: false,
            error: FundExchangePresentationError.fromApplicationError(
              failure.toFundExchangeError(),
            ),
          ),
        );
    }
  }

  void _onDone() {
    _subscription = null;
    if (isClosed || state.status == VirtualIbanStatus.pending) return;
    emit(state.copyWith(isLoading: false, isCreating: false));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
