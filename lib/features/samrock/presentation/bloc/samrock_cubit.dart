import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:bb_mobile/features/samrock/domain/usecases/complete_samrock_setup_usecase.dart';
import 'package:bb_mobile/features/samrock/presentation/bloc/samrock_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SamrockCubit extends Cubit<SamrockState> {
  final CompleteSamrockSetupUsecase _completeSamrockSetupUsecase;

  SamrockCubit({
    required CompleteSamrockSetupUsecase completeSamrockSetupUsecase,
  })  : _completeSamrockSetupUsecase = completeSamrockSetupUsecase,
        super(const SamrockState.initial());

  void parseUrl(String url) {
    final request = SamrockSetupRequest.tryParse(url);
    if (request == null) {
      emit(const SamrockState.error(message: 'Invalid SamRock setup URL'));
      return;
    }
    emit(SamrockState.parsed(request: request));
  }

  Future<void> confirmSetup() async {
    final currentState = state;
    if (currentState is! SamrockParsed) return;

    final request = currentState.request;
    emit(SamrockState.loading(request: request));

    try {
      final response = await _completeSamrockSetupUsecase.execute(request);
      if (response.success) {
        emit(SamrockState.success(request: request, response: response));
      } else {
        emit(SamrockState.error(
          message: response.message,
          request: request,
        ));
      }
    } catch (e) {
      emit(SamrockState.error(
        message: e.toString(),
        request: request,
      ));
    }
  }

  void reset() {
    emit(const SamrockState.initial());
  }
}
