import 'package:bb_mobile/features/recipients/domain/entities/cad_biller_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'cad_biller_view_model.freezed.dart';

@freezed
sealed class CadBillerViewModel with _$CadBillerViewModel {
  const factory CadBillerViewModel({
    required String payeeName,
    required String payeeCode,
  }) = _CadBillerViewModel;

  factory CadBillerViewModel.fromSummary(CadBillerSummary summary) {
    return CadBillerViewModel(
      payeeName: summary.payeeName,
      payeeCode: summary.payeeCode,
    );
  }
}
