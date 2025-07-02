import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_error.freezed.dart';

@freezed
sealed class LabelError with _$LabelError {
  const factory LabelError.notFound({required String label}) = LabelNotFound;
  const factory LabelError.unsupportedType(Type runtimeType) =
      UnsupportedLabelType;
  const factory LabelError.unexpected(String? message) = UnexpectedLabelError;
  const LabelError._();
}
