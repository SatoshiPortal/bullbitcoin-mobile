import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/usecases/pick_image_attachments_usecase.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/usecases/resolve_support_chat_user_id_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

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
    late _MockGetUserSummaryUsecase getUserSummaryUsecase;
    late ResolveSupportChatUserIdUsecase usecase;

    setUp(() {
      getUserSummaryUsecase = _MockGetUserSummaryUsecase();
      usecase = ResolveSupportChatUserIdUsecase(
        getUserSummaryUsecase: getUserSummaryUsecase,
      );
    });

    test('forwards the id when the core use-case answers', () async {
      when(
        () => getUserSummaryUsecase.execute(),
      ).thenAnswer((_) async => _userSummary);

      expect((await usecase.execute() as Ok).value, 'user-1');
    });

    test('a raw throw never escapes: it becomes the catch-all failure and the '
        'reason stays in logMessage', () async {
      when(
        () => getUserSummaryUsecase.execute(),
      ).thenThrow(Exception('token=SECRET at host=internal.bull'));

      final failure = (await usecase.execute() as Err).failure;

      expect(failure, isA<ExchangeSupportChatUnexpectedFailure>());
      expect(failure.logMessage, contains('internal.bull'));
    });
  });

  group('PickImageAttachmentsUsecase', () {
    test('forwards the repository result untouched', () async {
      final repository = _MockAttachmentPickerRepository();
      const failure = PermissionDeniedNeedsSettingsFailure();
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
