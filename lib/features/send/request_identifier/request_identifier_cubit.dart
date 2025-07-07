import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RequestIdentifierCubit extends Cubit<RequestIdentifierState> {
  RequestIdentifierCubit() : super(const RequestIdentifierState());

  Future<void> onScanned(String data) async {
    if (data.isEmpty) return;

    try {
      final request = await PaymentRequest.parse(data);
      emit(state.copyWith(request: request));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void updateRawRequest(String data) {
    if (data.isEmpty) return;
    emit(state.copyWith(rawRequest: data));
  }

  Future<void> validatePaymentRequest() async {
    if (state.rawRequest.isEmpty) return;
    try {
      final request = await PaymentRequest.parse(state.rawRequest);
      emit(state.copyWith(request: request));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
