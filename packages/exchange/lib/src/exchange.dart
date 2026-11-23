import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxCredentialUnavailableFailure, BbxTimeouts;
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import 'data/bbx_api_account_repository.dart';
import 'data/bbx_api_exchange_recipient_repository.dart';
import 'data/bbx_api_funding_repository.dart';
import 'data/bbx_api_kyc_repository.dart';
import 'data/bbx_api_limit_order_repository.dart';
import 'data/bbx_api_notification_datasource.dart';
import 'data/bbx_api_order_stats_repository.dart';
import 'data/bbx_api_order_repository.dart';
import 'data/bbx_api_support_chat_repository.dart';
import 'data/bbx_api_user_repository.dart';
import 'data/bbx_api_virtual_iban_repository.dart';
import 'data/exchange_notification_service.dart';
import 'data/exchange_kyc_configuration_repository.dart';
import 'data/pending_orders.dart';
import 'domain/entities/announcement.dart';
import 'domain/entities/default_wallet.dart';
import 'domain/entities/notification_message.dart';
import 'domain/entities/order_stats.dart';
import 'domain/entities/support_chat_message.dart';
import 'domain/entities/support_chat_message_attachment.dart';
import 'domain/entities/user_summary.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';
import 'domain/exchange_funding.dart';
import 'domain/exchange_kyc_configuration.dart';
import 'domain/exchange_limit_orders.dart';
import 'domain/exchange_orders.dart';
import 'domain/exchange_virtual_ibans.dart';

typedef _SaveUserPreference = Future<Result<void, ExchangeFailure>> Function(
  ExchangeEnvironment environment, {
  String? language,
  String? currency,
  bool? dcaEnabled,
  String? autoBuyEnabled,
  bool? emailNotificationsEnabled,
});
typedef _DefaultWalletOperations = ({
  Future<Result<DefaultWallets, ExchangeFailure>> Function() get,
  Future<Result<DefaultWallet, ExchangeFailure>> Function({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  })
  save,
  Future<Result<void, ExchangeFailure>> Function({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  })
  delete,
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
  Stream<Result<NotificationMessage, ExchangeFailure>> Function() messages,
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
  )
  _getAccount;
  final Future<Result<UserSummary, ExchangeFailure>> Function(
    ExchangeEnvironment?,
  )
  _getUserSummary;
  final Future<Result<List<Announcement>, ExchangeFailure>> Function(
    ExchangeEnvironment,
  )
  _listAnnouncements;
  final _SaveUserPreference _saveUserPreference;
  final _DefaultWalletOperations _defaultWallets;
  final ExchangeOrders Function(ExchangeEnvironment) _orders;
  final ExchangeChatOperations _chat;
  final ExchangeNotificationOperations _notifications;
  final ExchangeLimitOrders limitOrders;
  final ExchangeFunding funding;
  final ExchangeVirtualIbans virtualIbans;
  final ExchangeKycConfigurationRepository? _kyc;

  const Exchange._(
    this._hasPendingOrders,
    this._getOrderStats,
    this._uploadKycDocument,
    this._getAccount,
    this._getUserSummary,
    this._listAnnouncements,
    this._saveUserPreference,
    this._defaultWallets,
    this._orders,
    this._chat,
    this._notifications,
    this.limitOrders,
    this.funding,
    this.virtualIbans,
    this._kyc,
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
    Uri? paymentReturnUrl,
    ExchangeKycSetup? kyc,
  }) => _open(
    mainnetEndpoint: mainnetEndpoint,
    testnetEndpoint: testnetEndpoint,
    readSession: readSession,
    notifications: notifications,
    paymentReturnUrl: paymentReturnUrl,
    kyc: kyc,
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
    Uri? paymentReturnUrl,
    ExchangeKycSetup? kyc,
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
      bool checkCompletion = false,
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
            if (stale) return const Err(ExchangeOperationStaleFailure());
            if (checkCompletion) {
              switch (await sessionSnapshot()) {
                case Ok(value: final current) when current == value:
                  break;
                case _:
                  // An unverified completion may have committed a mutation.
                  // Never publish it into another session or retry the write.
                  return const Err(ExchangeOperationStaleFailure());
              }
            }
            return result;
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
    Future<Result<T, ExchangeFailure>> limitOrder<T>(
      ExchangeLimitOrderProblem problem,
      Future<Result<T, ExchangeFailure>> Function(BbxApiLimitOrderRepository)
      call,
    ) => withClient(
      (client, _) => call(BbxApiLimitOrderRepository(client)),
      untimed: true,
      credentialReadFailure: () =>
          ExchangeLimitOrderFailure(problem, 'Exchange credential unavailable'),
    );
    final fundingReturnUrl =
        paymentReturnUrl ?? Uri.parse('https://app.bullbitcoin.com');
    Future<Result<T, ExchangeFailure>> fund<T>(
      Future<Result<T, ExchangeFailure>> Function(BbxApiFundingRepository) call,
    ) => withClient(
      (client, _) => call(
        BbxApiFundingRepository(
          api: client,
          paymentReturnUrl: fundingReturnUrl,
        ),
      ),
      untimed: true,
      credentialReadFailure: () =>
          const ExchangeUnexpectedFailure('Exchange credential unavailable'),
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
        get: () => withClient(
          (client, _) =>
              BbxApiExchangeRecipientRepository(api: client)
                  .getDefaultWallets(),
          checkCompletion: true,
        ),
        save: ({required walletType, required address, existingRecipientId}) =>
            withClient(
              (client, _) =>
                  BbxApiExchangeRecipientRepository(api: client)
                      .saveDefaultWallet(
                        walletType: walletType,
                        address: address,
                        existingRecipientId: existingRecipientId,
                      ),
              checkCompletion: true,
            ),
        delete:
            ({required recipientId, required walletType, required address}) =>
                withClient(
                  (client, _) => BbxApiExchangeRecipientRepository(api: client)
                      .deleteDefaultWallet(
                        recipientId: recipientId,
                        walletType: walletType,
                        address: address,
                      ),
                  checkCompletion: true,
                ),
      ),
      (environment) => BbxApiOrderRepository(
        isTestnet: environment == ExchangeEnvironment.testnet,
        run: <T>(operation) => withClient<T>(
          (client, _) => operation(client),
          environment: environment,
          checkCompletion: true,
        ),
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
      ExchangeLimitOrdersImpl(
        list: () => limitOrder(
          ExchangeLimitOrderProblem.load,
          (repository) => repository.listActive(),
        ),
        get: (id) => limitOrder(
          ExchangeLimitOrderProblem.load,
          (repository) => repository.get(id),
        ),
        create: (draft) => limitOrder(
          ExchangeLimitOrderProblem.create,
          (repository) => repository.create(draft),
        ),
        cancel: (id) => limitOrder(
          ExchangeLimitOrderProblem.cancel,
          (repository) => repository.cancel(id),
        ),
        cancelAll: () => limitOrder(
          ExchangeLimitOrderProblem.cancel,
          (repository) => repository.cancelAll(),
        ),
        rate: (currency) => limitOrder(
          ExchangeLimitOrderProblem.load,
          (repository) => repository.getRate(currency),
        ),
      ),
      ExchangeFundingImpl(
        get: (method) => fund(
          (repository) => repository.getFundingDetails(fundingMethod: method),
        ),
        list: (jurisdiction) => fund(
          (repository) =>
              repository.listInstitutions(jurisdiction: jurisdiction),
        ),
        consent: () =>
            fund((repository) => repository.registerResponsibilityConsent()),
      ),
      ExchangeVirtualIbansImpl(
        find: (environment) => withClient(
          (client, _) => BbxApiVirtualIbanRepository(client).find(),
          environment: environment,
          untimed: true,
        ),
        create: (environment) => withClient(
          (client, _) => BbxApiVirtualIbanRepository(client).create(),
          environment: environment,
          untimed: true,
        ),
      ),
      kyc == null ? null : ExchangeKycConfigurationRepository(kyc),
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
  @useResult
  Future<Result<ExchangeKycConfiguration, ExchangeFailure>> loadKyc() async =>
      await _kyc?.load() ?? const Err(ExchangeUnexpectedFailure());

  @useResult
    required String fileName,
  }) => _uploadKycDocument(fileBytes: fileBytes, fileName: fileName);

  /// Reads the account, distinguishing an HTTP 401 from an absent local key.
  Future<Result<UserSummary, ExchangeFailure>> getAccount(
    ExchangeEnvironment environment,
  ) => _getAccount(environment);

  /// Reads the summary with the historical account-availability semantics.
  Future<Result<UserSummary, ExchangeFailure>> getUserSummary([
    ExchangeEnvironment? environment,
  ]) => _getUserSummary(environment);

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

  /// Binds operations to the caller's selected backend, not to a credential.
  /// Every request checks that the active session still matches that backend.
  ExchangeOrders orders(ExchangeEnvironment environment) =>
      _orders(environment);

  @useResult
  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets() =>
      _defaultWallets.get();

  @useResult
  Future<Result<DefaultWallet, ExchangeFailure>> saveDefaultWallet({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) => _defaultWallets.save(
    walletType: walletType,
    address: address,
    existingRecipientId: existingRecipientId,
  );

  @useResult
  Future<Result<void, ExchangeFailure>> deleteDefaultWallet({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) => _defaultWallets.delete(
    recipientId: recipientId,
    walletType: walletType,
    address: address,
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

  /// Broadcasts messages and recoverable failures from the active socket.
  /// An [Err] does not close the stream. Failures before opening a socket
  /// (such as an unavailable environment) are returned by the command only.
  Stream<Result<NotificationMessage, ExchangeFailure>> get notifications =>
      _notifications.messages();

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
  Future<Result<UserSummary, ExchangeFailure>> Function(ExchangeEnvironment?)?
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
  Future<Result<DefaultWallets, ExchangeFailure>> Function()? getDefaultWallets,
  Future<Result<DefaultWallet, ExchangeFailure>> Function({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  })?
  saveDefaultWallet,
  Future<Result<void, ExchangeFailure>> Function({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  })?
  deleteDefaultWallet,
  ExchangeOrders Function(ExchangeEnvironment)? orders,
  ExchangeChatOperations? chat,
  ExchangeNotificationOperations? notifications,
  ExchangeLimitOrders? limitOrders,
  ExchangeFunding? funding,
  ExchangeVirtualIbans? virtualIbans,
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
  (
    get:
        getDefaultWallets ??
        () => throw StateError('Unexpected default wallet read'),
    save:
        saveDefaultWallet ??
        ({required walletType, required address, existingRecipientId}) =>
            throw StateError('Unexpected default wallet write'),
    delete:
        deleteDefaultWallet ??
        ({required recipientId, required walletType, required address}) =>
            throw StateError('Unexpected default wallet removal'),
  ),
  orders ?? (_) => throw StateError('Unexpected order request'),
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
  limitOrders ??
      ExchangeLimitOrdersImpl(
        list: () => throw StateError('Unexpected limit order listing'),
        get: (_) => throw StateError('Unexpected limit order read'),
        create: (_) => throw StateError('Unexpected limit order create'),
        cancel: (_) => throw StateError('Unexpected limit order cancel'),
        cancelAll: () => throw StateError('Unexpected limit order bulk cancel'),
        rate: (_) => throw StateError('Unexpected limit order rate'),
      ),
  funding ??
      ExchangeFundingImpl(
        get: (_) => throw StateError('Unexpected funding details request'),
        list: (_) => throw StateError('Unexpected funding institution lookup'),
        consent: () => throw StateError('Unexpected funding consent'),
      ),
  virtualIbans ??
      ExchangeVirtualIbansImpl(
        find: (_) => throw StateError('Unexpected virtual IBAN lookup'),
        create: (_) => throw StateError('Unexpected virtual IBAN creation'),
      ),
);

Exchange exchangeWithTransportForTesting({
  required ExchangeSessionReader readSession,
  required OpenInventoryClient openClient,
  OpenInventoryClient? openUntimedClient,
}) => Exchange._open(
  mainnetEndpoint: Uri.parse('https://mainnet.example.invalid'),
  testnetEndpoint: Uri.parse('https://testnet.example.invalid'),
  readSession: readSession,
  openClient: openClient,
  openUntimedClient: openUntimedClient ?? openClient,
);
  null,
