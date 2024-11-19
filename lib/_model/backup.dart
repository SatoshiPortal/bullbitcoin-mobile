import 'package:bb_mobile/_model/bip329_label.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup.freezed.dart';
part 'backup.g.dart';

@freezed
class Backup with _$Backup {
  const factory Backup({
    @Default(1) int version,
    @Default(<String>[]) List<String> mnemonic,
    @Default(<String>[]) List<String> passphrases,
    @Default(<Bip329Label>[]) List<Bip329Label> labels,
    @Default(<String>[]) List<String> descriptors,
  }) = _Backup;

  factory Backup.fromJson(Map<String, dynamic> json) => _$BackupFromJson(json);

  const Backup._();

  bool get isEmpty =>
      mnemonic.isEmpty &&
      passphrases.isEmpty &&
      labels.isEmpty &&
      descriptors.isEmpty;
}
