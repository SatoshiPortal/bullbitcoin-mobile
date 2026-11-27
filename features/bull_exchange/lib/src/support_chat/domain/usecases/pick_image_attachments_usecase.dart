import 'package:exchange/exchange.dart';

import 'package:primitives/primitives.dart';

import '../repositories/attachment_picker_repository.dart';

import 'package:meta/meta.dart';

class PickImageAttachmentsUsecase {
  final AttachmentPickerRepository _repository;

  PickImageAttachmentsUsecase({required this._repository});

  @useResult
  Future<Result<List<SupportChatMessageAttachment>, ExchangeFailure>>
  execute() => _repository.pickImages();
}
