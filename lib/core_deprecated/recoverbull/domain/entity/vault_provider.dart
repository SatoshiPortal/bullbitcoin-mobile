import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';

enum VaultProvider {
  googleDrive,
  iCloud,
  customLocation;

  String displayName(BuildContext context) {
    switch (this) {
      case VaultProvider.googleDrive:
        return context.loc.recoverbullSelectGoogleDrive;
      case VaultProvider.iCloud:
        return context.loc.recoverbullSelectAppleIcloud;
      case VaultProvider.customLocation:
        return context.loc.recoverbullSelectCustomLocationProvider;
    }
  }

  String get iconPath {
    switch (this) {
      case VaultProvider.googleDrive:
        return Assets.misc.googleDrive.path;
      case VaultProvider.iCloud:
        return Assets.misc.icloud.path;
      case VaultProvider.customLocation:
        return Assets.misc.customLocation.path;
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case VaultProvider.googleDrive:
      case VaultProvider.iCloud:
        return context.loc.recoverbullSelectQuickAndEasy;
      case VaultProvider.customLocation:
        return context.loc.recoverbullSelectTakeYourTime;
    }
  }
}
