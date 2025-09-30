import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_provider.freezed.dart';

@freezed
sealed class VaultProvider with _$VaultProvider {
  const factory VaultProvider.googleDrive() = GoogleDrive;
  const factory VaultProvider.iCloud() = ICloud;
  const factory VaultProvider.fileSystem() = FileSystem;
}
