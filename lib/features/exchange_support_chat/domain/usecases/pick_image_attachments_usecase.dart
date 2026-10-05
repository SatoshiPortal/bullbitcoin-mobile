import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:meta/meta.dart';

class PickImageAttachmentsUsecase {
  final AttachmentPickerRepository _repository;

  PickImageAttachmentsUsecase({required this._repository});

  @useResult
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  execute() => _repository.pickImages();
}
