import 'package:bb_mobile/features/recipients/application/dtos/cad_biller_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cad_biller_view_model.freezed.dart';

@freezed
sealed class CadBillerViewModel with _$CadBillerViewModel {
  const factory CadBillerViewModel({
    required String payeeName,
    required String payeeCode,
  }) = _CadBillerViewModel;

  factory CadBillerViewModel.fromDto(CadBillerDto dto) {
    return CadBillerViewModel(
      payeeName: dto.payeeName,
      payeeCode: dto.payeeCode,
    );
  }
}
