import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/sell/domain/get_sell_confidential_sepa_availability_usecase_v2.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

final class SellPayoutStateV2 {
  final bool isLoading;
  final ConfidentialSepaAvailability? availability;
  final SellFailure? failure;

  const SellPayoutStateV2({
    this.isLoading = false,
    this.availability,
    this.failure,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SellPayoutStateV2 &&
          isLoading == other.isLoading &&
          availability == other.availability &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(isLoading, availability, failure);
}

class SellPayoutCubitV2 extends Cubit<SellPayoutStateV2> {
  final GetSellConfidentialSepaAvailabilityUsecaseV2 _getAvailability;

  SellPayoutCubitV2(this._getAvailability) : super(const SellPayoutStateV2());

  Future<void> load() async {
    if (state.isLoading || isClosed) return;
    emit(const SellPayoutStateV2(isLoading: true));
    final result = await _getAvailability.execute();
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => SellPayoutStateV2(availability: value),
      Err(:final failure) => SellPayoutStateV2(failure: failure),
    });
  }

  void virtualIbanActivated() {
    if (!isClosed) {
      emit(
        const SellPayoutStateV2(
          availability: ConfidentialSepaAvailability.ready,
        ),
      );
    }
  }
}
