import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_announcements_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_exchange_api_key_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockSaveExchangeApiKeyUsecase extends Mock
    implements SaveExchangeApiKeyUsecase {}

class _MockSaveUserPreferencesUsecase extends Mock
    implements SaveUserPreferencesUsecase {}

class _MockDeleteExchangeApiKeyUsecase extends Mock
    implements DeleteExchangeApiKeyUsecase {}

class _MockGetAnnouncementsUsecase extends Mock
    implements GetAnnouncementsUsecase {}

class _MockExchangeNotificationService extends Mock
    implements ExchangeNotificationService {}

class _MockSendSupportChatMessageUsecase extends Mock
    implements SendSupportChatMessageUsecase {}

void main() {
  late _MockGetExchangeUserSummaryUsecase getUserSummary;
  late _MockSaveExchangeApiKeyUsecase saveApiKey;
  late _MockSaveUserPreferencesUsecase savePreferences;
  late _MockDeleteExchangeApiKeyUsecase deleteApiKey;
  late _MockGetAnnouncementsUsecase getAnnouncements;
  late _MockExchangeNotificationService notificationService;
  late _MockSendSupportChatMessageUsecase sendSupportMessage;
  late ExchangeCubit cubit;

  setUp(() {
    getUserSummary = _MockGetExchangeUserSummaryUsecase();
    saveApiKey = _MockSaveExchangeApiKeyUsecase();
    savePreferences = _MockSaveUserPreferencesUsecase();
    deleteApiKey = _MockDeleteExchangeApiKeyUsecase();
    getAnnouncements = _MockGetAnnouncementsUsecase();
    notificationService = _MockExchangeNotificationService();
    sendSupportMessage = _MockSendSupportChatMessageUsecase();
    when(
      () => notificationService.messageStream,
    ).thenAnswer((_) => const Stream<NotificationMessage>.empty());
    cubit = ExchangeCubit(
      getExchangeUserSummaryUsecase: getUserSummary,
      saveExchangeApiKeyUsecase: saveApiKey,
      saveUserPreferencesUsecase: savePreferences,
      deleteExchangeApiKeyUsecase: deleteApiKey,
      getAnnouncementsUsecase: getAnnouncements,
      exchangeNotificationService: notificationService,
      sendSupportChatMessageUsecase: sendSupportMessage,
    );
  });

  tearDown(() => cubit.close());

  test(
    'credential storage preserves the captured environment and does not refresh',
    () async {
      final response = <String, dynamic>{'response': 'value'};
      when(
        () => saveApiKey.execute(apiKeyResponseData: response, isTestnet: true),
      ).thenAnswer((_) async {});

      await cubit.storeApiKey(response, isTestnet: true);

      verify(
        () => saveApiKey.execute(apiKeyResponseData: response, isTestnet: true),
      ).called(1);
      verifyNever(() => getUserSummary.execute());
      expect(cubit.state.saveApiKeyException, isNull);
    },
  );

  test('credential storage exposes only the fixed import error', () async {
    final response = <String, dynamic>{'response': 'bbak-secret'};
    when(
      () => saveApiKey.execute(apiKeyResponseData: response, isTestnet: false),
    ).thenThrow(SaveExchangeApiKeyException('bbak-upstream-secret'));

    await cubit.storeApiKey(response, isTestnet: false);

    expect(
      cubit.state.saveApiKeyException?.message,
      'Unable to import Bull Bitcoin credentials',
    );
    expect(
      cubit.state.saveApiKeyException.toString(),
      isNot(contains('bbak-')),
    );
  });

  test(
    'user-summary refresh reports failure without exposing details',
    () async {
      when(
        () => getUserSummary.execute(),
      ).thenThrow(GetExchangeUserSummaryException('bbak-upstream-secret'));

      final refreshed = await cubit.fetchUserSummary();

      expect(refreshed, isFalse);
      expect(
        cubit.state.getUserSummaryException?.message,
        'Unable to refresh Bull Bitcoin account',
      );
      expect(
        cubit.state.getUserSummaryException.toString(),
        isNot(contains('bbak-')),
      );
    },
  );

  test(
    'logout reaches logged-out state after credential deletion fails',
    () async {
      when(
        () => deleteApiKey.execute(),
      ).thenThrow(DeleteExchangeApiKeyException('bbak-storage-secret'));

      await cubit.logout();

      verify(() => deleteApiKey.execute()).called(1);
      expect(cubit.state.userSummary, isNull);
      expect(
        cubit.state.deleteApiKeyException?.message,
        'Unable to delete Bull Bitcoin credentials',
      );
      expect(
        cubit.state.deleteApiKeyException.toString(),
        isNot(contains('bbak-')),
      );
    },
  );
}
