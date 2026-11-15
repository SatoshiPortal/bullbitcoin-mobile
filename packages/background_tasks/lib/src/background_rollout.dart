import 'dart:io';

/// Maintainer-only rollout gate. Enable only after Android writer lifetime,
/// contention/process-death and iOS expiration checks pass on real devices.
/// This deliberately is not a user preference or a build environment override.
const backgroundSyncEnabled = false;

/// This rollout validates mobile headless engines only.
bool get backgroundSyncAvailable =>
    backgroundSyncEnabled && (Platform.isAndroid || Platform.isIOS);
