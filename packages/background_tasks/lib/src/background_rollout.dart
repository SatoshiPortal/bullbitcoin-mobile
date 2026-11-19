import 'dart:io';

/// Maintainer-only rollout gate, not a user preference or a build environment
/// override: the user turns background tasks on or off in the app.
const backgroundSyncEnabled = true;

/// This rollout validates mobile headless engines only.
bool get backgroundSyncAvailable =>
    backgroundSyncEnabled && (Platform.isAndroid || Platform.isIOS);
