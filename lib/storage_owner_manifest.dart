import 'package:legacy_storage/coordination.dart';

/// The split manifest shared by foreground and WorkManager.
const storageOwnerManifest = {...splitV1Owners, 'order_swaps'};
