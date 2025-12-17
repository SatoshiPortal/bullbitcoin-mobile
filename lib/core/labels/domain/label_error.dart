import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'label_error.freezed.dart';

@freezed
sealed class LabelError with _$LabelError {
  const factory LabelError.notFound({required String label}) = LabelNotFound;
  const factory LabelError.unsupportedType(Type runtimeType) =
      UnsupportedLabelType;
  const factory LabelError.unexpected(String? message) = UnexpectedLabelError;
  const factory LabelError.systemLabelCannotBeDeleted() =
      SystemLabelCannotBeDeletedError;
  const LabelError._();

  String toTranslated(BuildContext context) => when(
    notFound: (label) => context.loc.labelErrorNotFound(label),
    unsupportedType: (type) =>
        context.loc.labelErrorUnsupportedType(type.toString()),
    unexpected: (message) =>
        message != null ? context.loc.labelErrorUnexpected(message) : '',
    systemLabelCannotBeDeleted: () => context.loc.labelErrorSystemCannotDelete,
  );
}
