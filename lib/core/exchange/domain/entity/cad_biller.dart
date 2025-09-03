import 'package:freezed_annotation/freezed_annotation.dart';

part 'cad_biller.freezed.dart';

@freezed
sealed class CadBiller with _$CadBiller {
  const factory CadBiller({
    required String payeeCode,
    required String payeeName,
  }) = _CadBiller;
}
