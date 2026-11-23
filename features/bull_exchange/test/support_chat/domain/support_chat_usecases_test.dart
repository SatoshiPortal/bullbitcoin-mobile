import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/support_chat/domain/exchange_support_chat_failure.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_exchange/src/support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/pick_image_attachments_usecase.dart';
import 'package:bull_exchange/src/support_chat/domain/usecases/resolve_support_chat_user_id_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAttachmentPickerRepository extends Mock
    implements AttachmentPickerRepository {}

const _userSummary = UserSummary(
  userNumber: 1,
  userId: 'user-1',
  groups: [],
  profile: UserProfile(firstName: 'Bob', lastName: 'Builder'),
  email: 'bob@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  group('ResolveSupportChatUserIdUsecase', () {
    ResolveSupportChatUserIdUsecase build(
      Result<UserSummary, ExchangeFailure> result,
    ) => ResolveSupportChatUserIdUsecase(
      exchange: exchangeForTesting(getUserSummary: (_) async => result),
    );

    test('forwards the id when Exchange answers', () async {
      final usecase = build(const Ok(_userSummary));
      expect((await usecase.execute() as Ok).value, 'user-1');
    });

    test(
      'maps a refused summary without forwarding diagnostic detail',
      () async {
        final usecase = build(
          const Err(ExchangeAccountUnavailableFailure('internal.bull')),
        );

        final failure = (await usecase.execute() as Err).failure;

        expect(failure, isA<ExchangeSupportChatUnexpectedFailure>());
        expect(failure.logMessage, isNull);
      },
    );
  });

  group('PickImageAttachmentsUsecase', () {
    test('forwards the repository result untouched', () async {
      final repository = _MockAttachmentPickerRepository();
      const failure = PickFilesFailure('boom');
      when(() => repository.pickImages()).thenAnswer(
        (_) async =>
            const Err<
              List<SupportChatMessageAttachment>,
              ExchangeSupportChatFailure
            >(failure),
      );

      final usecase = PickImageAttachmentsUsecase(repository: repository);

      expect((await usecase.execute() as Err).failure, same(failure));
    });
  });
}
