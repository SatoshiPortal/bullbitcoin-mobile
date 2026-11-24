import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart';
import 'package:bull_exchange/src/sell/domain/sell_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

final class SellPayoutState {
  final bool isLoading;
  final ConfidentialSepaAvailability? availability;
  final SellFailure? failure;

  const SellPayoutState({
    this.isLoading = false,
    this.availability,
    this.failure,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellPayoutState &&
          isLoading == other.isLoading &&
          availability == other.availability &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(isLoading, availability, failure);
}

class SellPayoutCubit extends Cubit<SellPayoutState> {
  final GetSellConfidentialSepaAvailabilityUsecase _getAvailability;

  SellPayoutCubit(this._getAvailability) : super(const SellPayoutState());

  Future<void> load(FiatCurrency currency) async {
    if (state.isLoading || isClosed) return;
    emit(const SellPayoutState(isLoading: true));
    final result = await _getAvailability.execute(currency);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => SellPayoutState(availability: value),
      Err(:final failure) => SellPayoutState(failure: failure),
    });
  }

  void virtualIbanActivated() {
    if (!isClosed) {
      emit(
        const SellPayoutState(availability: ConfidentialSepaAvailability.ready),
      );
    }
  }
}
