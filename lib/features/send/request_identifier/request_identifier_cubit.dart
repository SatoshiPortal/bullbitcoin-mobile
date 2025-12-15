import 'package:bb_mobile/core_deprecated/utils/payment_request.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RequestIdentifierCubit extends Cubit<RequestIdentifierState> {
  RequestIdentifierCubit() : super(const RequestIdentifierState());

  void onScanned(String data) {
    if (data.isEmpty) return;

    try {
      PaymentRequest.parse(data);
      emit(state.copyWith(redirect: RequestIdentifierRedirect.toSend));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void updateRawRequest(String data) {
    if (data.isEmpty) return;
    emit(state.copyWith(rawRequest: data));
  }

  void validatePaymentRequest() {
    if (state.rawRequest.isEmpty) return;
    try {
      PaymentRequest.parse(state.rawRequest);
      emit(state.copyWith(redirect: RequestIdentifierRedirect.toSend));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
