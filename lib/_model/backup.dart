import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup.freezed.dart';
part 'backup.g.dart';

@freezed
class Backup with _$Backup {
  const factory Backup({
    @Default(1) int version,
    @Default('') String name,
    @Default(<String>[]) List<String> mnemonic,
    @Default('') String passphrase,
    @Default('') String network,
    @Default('') String layer,
    @Default('') String type,
    @Default('') String script,
    @Default('') String publicDescriptors,
  }) = _Backup;

  factory Backup.fromJson(Map<String, dynamic> json) => _$BackupFromJson(json);

  const Backup._();

  bool get isEmpty => mnemonic.isEmpty && passphrase.isEmpty;
}
