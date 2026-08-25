import 'package:permission_handler/permission_handler.dart';

/// Thin seam over `permission_handler`.
///
/// It exists so the decision logic above it, which refusal can still be retried in-app and which one has to send the user to the OS settings, is reachable from a unit test without a platform channel.
class PhotoLibraryPermissionDatasource {
  const PhotoLibraryPermissionDatasource();

  Future<PermissionStatus> status(Permission permission) => permission.status;

  Future<PermissionStatus> request(Permission permission) =>
      permission.request();
}
