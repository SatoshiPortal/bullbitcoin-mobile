import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

class PermissionDatasource {
  Future<PermissionResult> requestPhotoLibraryPermission() async {
    if (Platform.isIOS) {
      return _requestIOSPhotoPermission();
    } else if (Platform.isAndroid) {
      return _requestAndroidPhotoPermission();
    }
    return PermissionResult.granted;
  }

  Future<PermissionResult> _requestIOSPhotoPermission() async {
    final status = await Permission.photos.status;
    if (status.isGranted) {
      return PermissionResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    final requestedStatus = await Permission.photos.request();
    return requestedStatus.isGranted
        ? PermissionResult.granted
        : PermissionResult.denied;
  }

  Future<PermissionResult> _requestAndroidPhotoPermission() async {
    // Try photos permission first
    var photosStatus = await Permission.photos.status;
    if (photosStatus.isGranted) {
      return PermissionResult.granted;
    }

    if (photosStatus.isPermanentlyDenied) {
      // Fall back to storage permission
      return _requestAndroidStoragePermission();
    }

    final requestedPhotosStatus = await Permission.photos.request();
    if (requestedPhotosStatus.isGranted) {
      return PermissionResult.granted;
    }

    if (requestedPhotosStatus.isPermanentlyDenied) {
      return _requestAndroidStoragePermission();
    }

    return PermissionResult.denied;
  }

  Future<PermissionResult> _requestAndroidStoragePermission() async {
    final storageStatus = await Permission.storage.status;
    if (storageStatus.isGranted) {
      return PermissionResult.granted;
    }
    if (storageStatus.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    final requestedStorageStatus = await Permission.storage.request();
    return requestedStorageStatus.isGranted
        ? PermissionResult.granted
        : PermissionResult.denied;
  }

  bool get isAndroid => Platform.isAndroid;
}

