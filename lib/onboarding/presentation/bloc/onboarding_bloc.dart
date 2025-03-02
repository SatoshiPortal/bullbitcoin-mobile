import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState.initial()) {
    on<OnboardingWalletCreated>(_onWalletCreated);
  }

  Future<void> _onWalletCreated(
    OnboardingWalletCreated event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(const OnboardingState.walletCreationInProgress());

      emit(
        const OnboardingState.success(),
      );
    } catch (e) {
      emit(
        OnboardingState.failure(e),
      );
    }
  }
}
