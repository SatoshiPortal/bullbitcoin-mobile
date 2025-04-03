import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_provider.freezed.dart';

class BackupProviderEntity {
  final String name;
  final String iconPath;
  final String description;
  final String type;
  final bool isAvailable;

  const BackupProviderEntity({
    required this.name,
    required this.iconPath,
    required this.description,
    required this.type,
    this.isAvailable = true,
  });
}

@freezed
class VaultProvider with _$VaultProvider {
  const factory VaultProvider.googleDrive() = GoogleDrive;
  const factory VaultProvider.iCloud() = ICloud;
  const factory VaultProvider.fileSystem(String fileAsString) = FileSystem;
}
