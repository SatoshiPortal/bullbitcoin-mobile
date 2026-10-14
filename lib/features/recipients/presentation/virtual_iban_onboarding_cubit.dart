import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/watch_virtual_iban_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_iban_onboarding_cubit.freezed.dart';
part 'virtual_iban_onboarding_state.dart';

class VirtualIbanOnboardingCubit extends Cubit<VirtualIbanOnboardingState> {
  final WatchVirtualIbanUsecase _watchVirtualIbanUsecase;
  final GetAccountOwnerNameUsecase _getAccountOwnerNameUsecase;
  StreamSubscription<Result<VirtualIban?, RecipientsFailure>>? _subscription;

  VirtualIbanOnboardingCubit({
    required this._watchVirtualIbanUsecase,
    required this._getAccountOwnerNameUsecase,
  }) : super(const VirtualIbanOnboardingState());

  Future<void> start() async {
    emit(state.copyWith(failure: null));
    switch (await _getAccountOwnerNameUsecase.execute()) {
      case Ok(:final value):
        if (isClosed) return;
        emit(state.copyWith(accountOwnerName: value));
        await _watch(createIfAbsent: false);
      case Err(:final failure):
        if (isClosed) return;
        emit(state.copyWith(failure: failure));
    }
  }

  Future<void> activate() async {
    if (state.isCreating) return;
    emit(state.copyWith(isCreating: true, failure: null));
    await _watch(createIfAbsent: true);
  }

  Future<void> _watch({required bool createIfAbsent}) async {
    await _subscription?.cancel();
    if (isClosed) return;
    _subscription = _watchVirtualIbanUsecase
        .execute(createIfAbsent: createIfAbsent)
        .listen(_onResult);
  }

  void _onResult(Result<VirtualIban?, RecipientsFailure> result) {
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            step: switch (value) {
              null => VirtualIbanOnboardingStep.intro,
              PendingVirtualIban() => VirtualIbanOnboardingStep.activating,
              ActiveVirtualIban() => VirtualIbanOnboardingStep.active,
            },
            virtualIban: value is ActiveVirtualIban ? value : null,
            isCreating: false,
            failure: null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isCreating: false, failure: failure));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }
}
