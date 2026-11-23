import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxCredentialUnavailableFailure, BbxTimeouts;
import 'package:primitives/primitives.dart';

import 'data/bbx_api_account_repository.dart';
import 'data/bbx_api_kyc_repository.dart';
import 'data/bbx_api_notification_datasource.dart';
import 'data/bbx_api_order_stats_repository.dart';
import 'data/bbx_api_support_chat_repository.dart';
import 'data/bbx_api_user_repository.dart';
import 'data/exchange_notification_service.dart';
import 'data/pending_orders.dart';
import 'domain/entities/announcement.dart';
import 'domain/entities/notification_message.dart';
import 'domain/entities/order_stats.dart';
import 'domain/entities/support_chat_message.dart';
import 'domain/entities/support_chat_message_attachment.dart';
import 'domain/entities/user_summary.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';

typedef _SaveUserPreference = Future<Result<void, ExchangeFailure>> Function(
  ExchangeEnvironment environment, {
  String? language,
  String? currency,
  bool? dcaEnabled,
  String? autoBuyEnabled,
  bool? emailNotificationsEnabled,
});
typedef ExchangeSessionReader =
    Future<
      Result<
        ({ExchangeEnvironment environment, int epoch, String? apiKey}),
        ExchangeFailure
      >
    >
    Function();

typedef ExchangeChatOperations = ({
  Future<Result<List<SupportChatMessage>, ExchangeFailure>> Function({
    int? page,
    int? pageSize,
  })
  getMessages,
  Future<Result<void, ExchangeFailure>> Function({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  })
  sendMessage,
  Future<Result<SupportChatMessageAttachment, ExchangeFailure>> Function(String)
  getAttachment,
});

typedef ExchangeNotificationBindings = ({
  Future<Result<ExchangeEnvironment, ExchangeFailure>> Function()
  readEnvironment,
  Future<Result<String?, Failure>> Function({required bool isTestnet}) readKey,
});

typedef ExchangeNotificationOperations = ({
  Stream<NotificationMessage> Function() messages,
  Future<Result<void, ExchangeFailure>> Function() connect,
  Future<Result<void, ExchangeFailure>> Function() reconnect,
  void Function() disconnect,
  Future<void> Function() close,
});

/// Bull Bitcoin exchange capabilities.
final class Exchange {
  final Future<Result<bool, ExchangeFailure>> Function() _hasPendingOrders;
  final Future<Result<OrderStatsResponse, ExchangeFailure>> Function()
  _getOrderStats;
  final Future<Result<void, ExchangeFailure>> Function({
    required List<int> fileBytes,
    required String fileName,
  })
  _uploadKycDocument;
  final Future<Result<UserSummary, ExchangeFailure>> Function(
    ExchangeEnvironment,
  ) _getAccount,
      _getUserSummary;
  final Future<Result<List<Announcement>, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _listAnnouncements;
  final _SaveUserPreference _saveUserPreference;
  final ExchangeChatOperations _chat;
  final ExchangeNotificationOperations _notifications;

  const Exchange._(
    this._hasPendingOrders,
    this._getOrderStats,
    this._uploadKycDocument,
    this._getAccount,
    this._getUserSummary,
    this._listAnnouncements,
    this._saveUserPreference,
    this._chat,
    this._notifications,
  );

  /// Opens the capability without doing I/O. [readSession] must return an
  /// authoritative snapshot of the current session; its epoch must change when
  /// the environment or access changes, even if the same key is later reused.
  /// The credential is never published by an Exchange operation.
  static Exchange open({
    required Uri mainnetEndpoint,
    required Uri testnetEndpoint,
    required ExchangeSessionReader readSession,
    ExchangeNotificationBindings? notifications,
  }) => _open(
    mainnetEndpoint: mainnetEndpoint,
    testnetEndpoint: testnetEndpoint,
    readSession: readSession,
    notifications: notifications,
    openClient: (endpoint, readKey) => Bbx.open(
      endpoint: endpoint.toString(),
      readActiveApiKey: readKey,
      timeouts: BbxTimeouts.standard,
    ),
    openUntimedClient: (endpoint, readKey) =>
        Bbx.open(endpoint: endpoint.toString(), readActiveApiKey: readKey),
  );

  static Exchange _open({
    required Uri mainnetEndpoint,
    required Uri testnetEndpoint,
    required ExchangeSessionReader readSession,
    required OpenInventoryClient openClient,
    required OpenInventoryClient openUntimedClient,
    ExchangeNotificationBindings? notifications,
  }) {
    Future<Result<InventorySession, ExchangeFailure>> sessionSnapshot() async =>
        (await readSession()).map(
          (session) => (
            endpoint: switch (session.environment) {
              ExchangeEnvironment.mainnet => mainnetEndpoint,
              ExchangeEnvironment.testnet => testnetEndpoint,
            },
            environment: session.environment,
            epoch: session.epoch,
            apiKey: session.apiKey,
          ),
        );

    Future<Result<T, ExchangeFailure>> withClient<T>(
      Future<Result<T, ExchangeFailure>> Function(Bbx, Bbx Function())
      operation, {
      ExchangeEnvironment? environment,
      ExchangeFailure Function()? credentialReadFailure,
      bool untimed = false,
    }) async {
      switch (await sessionSnapshot()) {
        case Err(failure: ExchangeCredentialReadFailure())
            when credentialReadFailure != null:
          return Err(credentialReadFailure());
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value)
            when environment != null && value.environment != environment:
          return const Err(ExchangeOperationStaleFailure());
        case Ok(:final value):
          var stale = false;
          Future<Result<String?, BbxCredentialUnavailableFailure>>
          readKey() async {
            if (await sessionSnapshot() case Ok(value: final current)
                when current == value) {
              return Ok(value.apiKey);
            }
            stale = true;
            return const Err(BbxCredentialUnavailableFailure());
          }
          final client = (untimed ? openUntimedClient : openClient)(
            value.endpoint,
            readKey,
          );
          Bbx? untimedClient;
          try {
            final result = await operation(
              client,
              () => untimed
                  ? client
                  : untimedClient ??= openUntimedClient(
                      value.endpoint,
                      readKey,
                    ),
            );
            return stale ? const Err(ExchangeOperationStaleFailure()) : result;
          } finally {
            untimedClient?.dispose();
            client.dispose();
          }
      }
    }

    final inventory = PendingOrders(
      readSession: sessionSnapshot,
      openClient: openClient,
    );
    ExchangeNotificationService? notificationService;
    bool closed = false;
    ExchangeNotificationService service() {
      if (closed) throw StateError('Exchange has closed');
      Future<Result<String?, Failure>> readKey(bool isTestnet) async {
        if (notifications case final bindings?) {
          return bindings.readKey(isTestnet: isTestnet);
        }
        return (await readSession()).map(
          (session) =>
              (session.environment == ExchangeEnvironment.testnet) == isTestnet
              ? session.apiKey
              : null,
        );
      }

      return notificationService ??= ExchangeNotificationService(
        mainnetDatasource: BbxApiNotificationDatasource(
          baseUrl: mainnetEndpoint.toString(),
          readApiKey: () => readKey(false),
        ),
        testnetDatasource: BbxApiNotificationDatasource(
          baseUrl: testnetEndpoint.toString(),
          readApiKey: () => readKey(true),
        ),
        readEnvironment:
            notifications?.readEnvironment ??
            () async => (await readSession()).map((s) => s.environment),
      );
    }

    return Exchange._(
      inventory.hasPendingOrders,
      () => withClient(
        (client, _) => BbxApiOrderStatsRepository(api: client).getOrderStats(),
      ),
      ({required fileBytes, required fileName}) => withClient(
        (client, _) => BbxApiKycRepository(api: client).uploadDocument(
          fileBytes: fileBytes,
          fileName: fileName,
          docType: 'ID',
          sourceDetail: 'SECURE_UPLOAD',
        ),
      ),
      (environment) => withClient(
        (client, _) => BbxApiAccountRepository(client).getAccount(),
        environment: environment,
        credentialReadFailure: ExchangeAccountUnavailableFailure.new,
      ),
      (environment) => withClient(
        (client, _) => BbxApiUserRepository(api: client).getUserSummary(),
        environment: environment,
      ),
      (environment) => withClient(
        (client, _) => BbxApiUserRepository(api: client).listAnnouncements(),
        environment: environment,
      ),
      (
        environment, {
        language,
        currency,
        dcaEnabled,
        autoBuyEnabled,
        emailNotificationsEnabled,
      }) => withClient(
        (client, _) => BbxApiUserRepository(api: client).saveUserPreference(
          language: language,
          currency: currency,
          dcaEnabled: dcaEnabled,
          autoBuyEnabled: autoBuyEnabled,
          emailNotificationsEnabled: emailNotificationsEnabled,
        ),
        environment: environment,
      ),
      (
        getMessages: ({page, pageSize}) => withClient(
          (timed, getUntimed) => BbxApiSupportChatRepository(
            users: timed.users,
            commcenter: getUntimed().commcenter,
          ).getMessages(page: page, pageSize: pageSize),
          credentialReadFailure: ExchangeChatLoadMessagesFailure.new,
        ),
        sendMessage: ({required text, attachments}) => withClient(
          (client, _) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).sendMessage(text: text, attachments: attachments),
          untimed: true,
          credentialReadFailure: ExchangeChatSendMessageFailure.new,
        ),
        getAttachment: (attachmentId) => withClient(
          (client, _) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).getMessageAttachment(attachmentId),
          untimed: true,
          credentialReadFailure: ExchangeChatLoadAttachmentFailure.new,
        ),
      ),
      (
        messages: () => service().messageStream,
        connect: () => service().connect(),
        reconnect: () => service().reconnect(),
        disconnect: () => notificationService?.disconnect(),
        close: () async {
          if (closed) return;
          closed = true;
          await notificationService?.dispose();
        },
      ),
    );
  }

  /// Returns false only after scanning a complete, stable session inventory.
  /// A signed-out account cannot establish absence.
  Future<Result<bool, ExchangeFailure>> hasPendingOrders() =>
      _hasPendingOrders();

  Future<Result<OrderStatsResponse, ExchangeFailure>> getOrderStats() =>
      _getOrderStats();

  Future<Result<void, ExchangeFailure>> uploadKycDocument({
    required List<int> fileBytes,
    required String fileName,
  }) => _uploadKycDocument(fileBytes: fileBytes, fileName: fileName);

  /// Reads the account, distinguishing an HTTP 401 from an absent local key.
  Future<Result<UserSummary, ExchangeFailure>> getAccount(
    ExchangeEnvironment environment,
  ) => _getAccount(environment);

  /// Reads the summary with the historical account-availability semantics.
  Future<Result<UserSummary, ExchangeFailure>> getUserSummary(
    ExchangeEnvironment environment,
  ) => _getUserSummary(environment);

  Future<Result<List<Announcement>, ExchangeFailure>> listAnnouncements(
    ExchangeEnvironment environment,
  ) => _listAnnouncements(environment);

  /// Replaces the account's preference set. Supply all existing values that
  /// should be retained when changing only one field.
  Future<Result<void, ExchangeFailure>> saveUserPreference(
    ExchangeEnvironment environment, {
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  }) => _saveUserPreference(
    environment,
    language: language,
    currency: currency,
    dcaEnabled: dcaEnabled,
    autoBuyEnabled: autoBuyEnabled,
    emailNotificationsEnabled: emailNotificationsEnabled,
  );

  Future<Result<List<SupportChatMessage>, ExchangeFailure>> getSupportMessages({
    int? page,
    int? pageSize,
  }) => _chat.getMessages(page: page, pageSize: pageSize);

  Future<Result<void, ExchangeFailure>> sendSupportMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) => _chat.sendMessage(text: text, attachments: attachments);

  Future<Result<SupportChatMessageAttachment, ExchangeFailure>>
  getSupportAttachment(String attachmentId) =>
      _chat.getAttachment(attachmentId);

  Stream<NotificationMessage> get notifications => _notifications.messages();

  Future<Result<void, ExchangeFailure>> connectNotifications() =>
      _notifications.connect();

  Future<Result<void, ExchangeFailure>> reconnectNotifications() =>
      _notifications.reconnect();

  void disconnectNotifications() => _notifications.disconnect();

  Future<void> close() => _notifications.close();
}

/// Builds the public capability with scenario-controlled results.
Exchange exchangeForTesting({
  Future<Result<bool, ExchangeFailure>> Function()? hasPendingOrders,
  Future<Result<OrderStatsResponse, ExchangeFailure>> Function()? getOrderStats,
  Future<Result<void, ExchangeFailure>> Function({
    required List<int> fileBytes,
    required String fileName,
  })?
  uploadKycDocument,
  Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeEnvironment)?
  getAccount,
  Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeEnvironment)?
  getUserSummary,
  Future<Result<List<Announcement>, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )?
  listAnnouncements,
  Future<Result<void, ExchangeFailure>> Function(
    ExchangeEnvironment, {
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  })?
  saveUserPreference,
  ExchangeChatOperations? chat,
  ExchangeNotificationOperations? notifications,
}) => Exchange._(
  hasPendingOrders ?? () => throw StateError('Unexpected inventory request'),
  getOrderStats ?? () => throw StateError('Unexpected statistics request'),
  uploadKycDocument ??
      ({required fileBytes, required fileName}) =>
          throw StateError('Unexpected document upload'),
  getAccount ?? (_) => throw StateError('Unexpected account request'),
  getUserSummary ?? (_) => throw StateError('Unexpected user summary request'),
  listAnnouncements ??
      (_) => throw StateError('Unexpected announcements request'),
  saveUserPreference ??
      (
        _, {
        language,
        currency,
        dcaEnabled,
        autoBuyEnabled,
        emailNotificationsEnabled,
      }) => throw StateError('Unexpected preference write'),
  chat ??
      (
        getMessages: ({page, pageSize}) =>
            throw StateError('Unexpected chat history request'),
        sendMessage: ({required text, attachments}) =>
            throw StateError('Unexpected chat send'),
        getAttachment: (_) =>
            throw StateError('Unexpected chat attachment request'),
      ),
  notifications ??
      (
        messages: () => const Stream.empty(),
        connect: () => throw StateError('Unexpected notification connect'),
        reconnect: () => throw StateError('Unexpected notification reconnect'),
        disconnect: () {},
        close: () async {},
      ),
);

Exchange exchangeWithTransportForTesting({
  required ExchangeSessionReader readSession,
  required OpenInventoryClient openClient,
}) => Exchange._open(
  mainnetEndpoint: Uri.parse('https://mainnet.example.invalid'),
  testnetEndpoint: Uri.parse('https://testnet.example.invalid'),
  readSession: readSession,
  openClient: openClient,
  openUntimedClient: openClient,
);
