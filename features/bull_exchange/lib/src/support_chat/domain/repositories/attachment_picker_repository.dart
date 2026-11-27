import 'package:exchange/exchange.dart';

import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

/// Picks images from the device photo library and turns them into chat attachments.
///
/// The photo library is an external system, so the permission dance and the picker plugin live behind this contract, and the feature above it only ever sees entities and failures.
abstract interface class AttachmentPickerRepository {
  /// Returns the picked attachments, or an empty list when the user dismissed the picker without choosing anything, since a cancellation is not a failure.
  @useResult
  Future<Result<List<SupportChatMessageAttachment>, ExchangeFailure>>
  pickImages();
}
