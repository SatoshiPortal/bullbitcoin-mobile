import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RequestIdentifierCubit extends Cubit<RequestIdentifierState> {
  RequestIdentifierCubit() : super(const RequestIdentifierState());

  // Parsing a scanned/pasted string is the data boundary for this screen: it
  // talks directly to PaymentRequest.parse (no use-case beneath it), so the
  // one try/catch lives here. The raw reason is logged; the UI only ever sees
  // the sanitized SendFailure.
  Future<void> onScanned(String data) => _parseAndRedirect(data);

  void updateRawRequest(String data) {
    if (data.isEmpty) return;
    emit(state.copyWith(rawRequest: data, failure: null));
  }

  Future<void> validatePaymentRequest() => _parseAndRedirect(state.rawRequest);

  Future<void> _parseAndRedirect(String data) async {
    if (data.isEmpty) return;

    try {
      await PaymentRequest.parse(data);
      emit(state.copyWith(redirect: RequestIdentifierRedirect.toSend));
    } catch (e, st) {
      log.warning('Invalid payment request', error: e, trace: st);
      emit(
        state.copyWith(
          // Type name only — the pasted text may be a mis-typed secret, so the
          // raw reason must never be persisted ([[no-secret-logging]]).
          failure: SendInvalidPaymentRequestGenericFailure(
            e.runtimeType.toString(),
          ),
        ),
      );
    }
  }
}
