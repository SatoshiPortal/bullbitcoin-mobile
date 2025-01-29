import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateDefaultWalletsUseCase createDefaultWalletsUseCase,
  })  : _createDefaultWalletsUseCase = createDefaultWalletsUseCase,
        super(const OnboardingState.initial()) {
    on<OnboardingWalletCreated>(_onWalletCreated);
  }

  final CreateDefaultWalletsUseCase _createDefaultWalletsUseCase;

  Future<void> _onWalletCreated(
    OnboardingWalletCreated event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      // Todo: uncomment when use case is implemented
      //emit(const OnboardingState.walletCreationInProgress());
      await _createDefaultWalletsUseCase.execute();
      /* TODO: uncomment when use case is implemented 
      emit(
        const OnboardingState.success(),
      );*/
    } catch (e) {
      emit(
        OnboardingState.failure(e),
      );
    }
  }
}
