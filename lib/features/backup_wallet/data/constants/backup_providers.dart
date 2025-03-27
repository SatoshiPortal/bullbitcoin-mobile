//the hard-coded list of providers (backupProviders) should be to the presentation/UI layer even though it is an entity, since it's UI-specific data.
import 'package:bb_mobile/features/backup_wallet/domain/entities/backup_provider_entity.dart';

const List<BackupProviderEntity> backupProviders = [
  BackupProviderEntity(
    name: 'Google Drive',
    iconPath: 'assets/google_drive.png',
    description: 'Quick & easy',
    type: 'google_drive',
  ),
  BackupProviderEntity(
    name: 'Apple iCloud',
    iconPath: 'assets/icloud.png',
    description: 'Quick & easy',
    type: 'icloud',
  ),
  BackupProviderEntity(
    name: 'Custom location',
    iconPath: 'assets/custom_location.png',
    description: 'Take your time',
    type: 'custom',
  ),
];
