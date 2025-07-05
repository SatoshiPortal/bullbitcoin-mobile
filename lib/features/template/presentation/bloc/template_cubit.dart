import 'package:bb_mobile/features/template/domain/collect_ip_address_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'template_cubit.freezed.dart';
part 'template_state.dart';

class TemplateCubit extends Cubit<TemplateState> {
  final CollectIpAddressUsecase _usecase;

  TemplateCubit({required CollectIpAddressUsecase usecase})
    : _usecase = usecase,
      super(const TemplateState());

  void updateInputText(String text) {
    emit(state.copyWith(input: text));
  }

  void clearError() {
    emit(state.copyWith(error: '', status: const TemplateStatus.initial()));
  }

  Future<void> executeTemplateOperation() async {
    try {
      emit(
        state.copyWith(
          isLoading: true,
          status: const TemplateStatus.loading(),
          error: '',
        ),
      );

      await _usecase.call();

      emit(
        state.copyWith(
          isLoading: false,
          status: const TemplateStatus.success(
            message: 'Operation completed successfully',
          ),
          result: 'Operation completed for: ${state.input}',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          status: TemplateStatus.failure(message: e.toString()),
          error: e.toString(),
        ),
      );
    }
  }

  void reset() {
    emit(const TemplateState());
  }
}
