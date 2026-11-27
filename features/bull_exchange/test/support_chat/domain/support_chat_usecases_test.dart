import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/pick_image_attachments_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttachmentPickerRepository extends Mock
    implements AttachmentPickerRepository {}

void main() {
  group('PickImageAttachmentsUsecase', () {
    test('forwards the repository result untouched', () async {
      final repository = _MockAttachmentPickerRepository();
      const failure = ExchangeChatPickImagesFailure('boom');
      when(() => repository.pickImages()).thenAnswer(
        (_) async =>
            const Err<List<SupportChatMessageAttachment>, ExchangeFailure>(
              failure,
            ),
      );

      final usecase = PickImageAttachmentsUsecase(repository: repository);

      expect((await usecase.execute() as Err).failure, same(failure));
    });
  });
}
