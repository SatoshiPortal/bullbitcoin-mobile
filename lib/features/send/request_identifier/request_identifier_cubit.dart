import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RequestIdentifierCubit extends Cubit<RequestIdentifierState> {
  final DetectBitcoinStringUsecase _detect;

  RequestIdentifierCubit({DetectBitcoinStringUsecase? detect})
    : _detect = detect ?? DetectBitcoinStringUsecase(),
      super(const RequestIdentifierState());

  Future<void> onScanned(String data) async {
    if (data.isEmpty) return;
    await _validate(data);
  }

  void updateRawRequest(String data) {
    // Also clears on an empty field: returning early here left the previous
    // failure on screen after the user wiped the input to start over.
    emit(state.copyWith(rawRequest: data, failure: null));
  }

  Future<void> validatePaymentRequest() async {
    if (state.rawRequest.isEmpty) return;
    await _validate(state.rawRequest);
  }

  Future<void> _validate(String data) async {
    try {
      await _detect.execute(data: data);
      emit(
        state.copyWith(
          redirect: RequestIdentifierRedirect.toSend,
          failure: null,
        ),
      );
    } catch (e) {
      final reason = e.runtimeType.toString();
      log.warning('Pasted text is not a payment request', error: reason);
      emit(
        state.copyWith(
          failure: SendInvalidPaymentRequestFailure(logMessage: reason),
        ),
      );
    }
  }
}
