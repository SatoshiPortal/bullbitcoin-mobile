part of 'template_cubit.dart';

@freezed
sealed class TemplateStatus with _$TemplateStatus {
  const factory TemplateStatus.initial() = TemplateInitial;
  const factory TemplateStatus.loading() = TemplateLoading;
  const factory TemplateStatus.success({String? message}) = TemplateSuccess;
  const factory TemplateStatus.failure({required String message}) =
      TemplateFailure;
}

@freezed
abstract class TemplateState with _$TemplateState {
  const factory TemplateState({
    @Default(TemplateStatus.initial()) TemplateStatus status,
    @Default('') String input,
    @Default('') String result,
    @Default(false) bool isLoading,
    @Default('') String error,
    Map<String, dynamic>? featureData,
  }) = _TemplateState;
  const TemplateState._();

  bool get hasValidInput => input.isNotEmpty && input.length >= 3;
  bool get canProceed => hasValidInput && !isLoading;
  bool get hasError => error.isNotEmpty;
  bool get hasData => featureData != null;
}
