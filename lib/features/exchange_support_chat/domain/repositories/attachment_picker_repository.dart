import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// Picks images from the device photo library and turns them into chat attachments.
///
/// The photo library is an external system, so the permission dance and the picker plugin live behind this contract, and the feature above it only ever sees entities and failures.
abstract interface class AttachmentPickerRepository {
  /// Returns the picked attachments, or an empty list when the user dismissed the picker without choosing anything, since a cancellation is not a failure.
  @useResult
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  pickImages();
}
