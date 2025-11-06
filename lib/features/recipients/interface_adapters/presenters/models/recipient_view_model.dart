import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipient_view_model.freezed.dart';

@freezed
sealed class RecipientViewModel with _$RecipientViewModel {
  const factory RecipientViewModel({
    required String id,
    required RecipientType type,
  }) = _RecipientViewModel;
  const RecipientViewModel._();

  factory RecipientViewModel.fromDto(RecipientDto dto) {
    return RecipientViewModel(id: dto.recipientId, type: dto.recipientType);
  }

  String get jurisdictionCode => type.jurisdictionCode;
}
