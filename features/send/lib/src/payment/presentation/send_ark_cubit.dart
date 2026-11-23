import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/usecases/recognize_ark_address_usecase.dart';
import '../domain/send_failure.dart';

sealed class SendArkState {
  const SendArkState();
}

final class SendArkHidden extends SendArkState {
  const SendArkHidden();
}

final class SendArkLoading extends SendArkState {
  const SendArkLoading();
}

final class SendArkReady extends SendArkState {
  final SendArkRequest request;
  const SendArkReady(this.request);
}

final class SendArkUnavailable extends SendArkState {
  final SendFailure failure;
  const SendArkUnavailable(this.failure);
}

final class SendArkCubit extends Cubit<SendArkState> {
  final RecognizeArkAddressUsecase _recognize;
  int _epoch = 0;
  SendArkCubit(RecognizeArkAddressUsecase? recognize)
    : _recognize = recognize ?? const RecognizeArkAddressUsecase(null),
      super(const SendArkHidden());
  Future<void> resolve({
    required String input,
    required Network? network,
    required bool coinControl,
    required bool sweep,
    required bool silentPayments,
    required bool multipleRecipients,
  }) async {
    if (isClosed) return;
    final epoch = ++_epoch;
    final usecase = _recognize;
    if (network == null || !usecase.recognizes(input, network)) {
      emit(const SendArkHidden());
      return;
    }
    emit(const SendArkLoading());
    final result = await usecase.execute(
      input: input,
      network: network,
      restricted: coinControl || sweep || silentPayments || multipleRecipients,
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case Ok(value: null):
        emit(const SendArkHidden());
      case Ok(value: final request?):
        emit(SendArkReady(request));
      case Err(:final failure):
        emit(SendArkUnavailable(failure));
    }
  }
}
