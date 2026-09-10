// Public constructor names differ from private backing fields to preserve immutable views.
// ignore_for_file: prefer_initializing_formals

import 'dart:collection';

import '../../domain/entities/drive_file_metadata.dart';
import '../../domain/entities/encrypted_vault.dart';
import '../../domain/recoverbull_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'state.mapper.dart';

@MappableClass(
  generateMethods:
      GenerateMethods.stringify | GenerateMethods.equals | GenerateMethods.copy,
)
final class RecoverBullGoogleDriveState
    with RecoverBullGoogleDriveStateMappable {
  final bool isLoading;
  final RecoverBullFailure? failure;
  final List<DriveFileMetadata> _driveMetadata;
  final EncryptedVault? selectedVault;

  const RecoverBullGoogleDriveState({
    this.isLoading = false,
    this.failure,
    List<DriveFileMetadata> driveMetadata = const [],
    this.selectedVault,
  }) : _driveMetadata = driveMetadata;

  List<DriveFileMetadata> get driveMetadata =>
      UnmodifiableListView(_driveMetadata);
}
