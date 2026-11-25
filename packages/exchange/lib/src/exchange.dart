import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxCredentialUnavailableFailure, BbxTimeouts;
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';

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
import 'domain/entities/confidential_sepa_availability.dart';
import 'domain/entities/default_wallet.dart';
import 'domain/entities/notification_message.dart';
import 'domain/entities/order_stats.dart';
import 'domain/entities/support_chat_message.dart';
import 'domain/entities/support_chat_message_attachment.dart';
import 'domain/entities/user_summary.dart';
import 'domain/entities/virtual_iban.dart';
import 'domain/exchange_access.dart';
import 'domain/exchange_availability.dart';
import 'domain/exchange_basic_auth.dart';
import 'domain/exchange_account_deletion_outcome.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';
import 'domain/exchange_funding.dart';
import 'domain/exchange_kyc_configuration.dart';
import 'domain/exchange_limit_orders.dart';
import 'domain/exchange_orders.dart';
import 'domain/exchange_virtual_ibans.dart';
import 'setup/exchange_access_lifecycle.dart';
import 'recipients/exchange_recipients.dart';
import 'session/complete_exchange_authentication_usecase.dart';
import 'session/exchange_auth_repository_impl.dart';
import 'session/exchange_web_auth_datasource.dart';
import 'session/expire_exchange_session_usecase.dart';
import 'session/get_exchange_account_usecase.dart';
import 'session/get_exchange_announcements_usecase.dart';
import 'session/get_exchange_web_settings_usecase.dart';
import 'session/get_unread_support_message_count_usecase.dart';
import 'session/mark_support_messages_read_usecase.dart';
import 'session/save_exchange_preferences_usecase.dart';
import 'session/watch_exchange_notifications_usecase.dart';

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
  Future<Result<int, ExchangeFailure>> Function() getUnreadCount,
  Future<Result<void, ExchangeFailure>> Function() markAllRead,
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

typedef ExchangeWebAuthEndpoints = ({Uri mainnet, Uri testnet});

enum _CompletionCheck { none, read, write }

/// Bull Bitcoin exchange capabilities.
final class Exchange {
  final Future<Result<bool, ExchangeFailure>> Function() _hasPendingOrders;
  final Future<Result<OrderStatistics, ExchangeFailure>> Function()
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
  final Future<Result<ConfidentialSepaAvailability, ExchangeFailure>> Function()
  _getConfidentialSepaAvailability;
  final ExchangeAccessLifecycle? _access;
  final Preferences? _sessionPreferences;
  final ExchangeWebAuthEndpoints? _webAuthEndpoints;
  final ExchangeBasicAuthStore? _basicAuth;
  final ExchangeRecipients recipients;

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
    this._getConfidentialSepaAvailability,
    this._access,
    this.recipients,
    this._sessionPreferences,
    this._webAuthEndpoints,
    this._basicAuth,
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
    ExchangeAccessLifecycle? access,
    Preferences? sessionPreferences,
    ExchangeWebAuthEndpoints? webAuthEndpoints,
    ExchangeBasicAuthStore? basicAuth,
  }) => _open(
    mainnetEndpoint: mainnetEndpoint,
    testnetEndpoint: testnetEndpoint,
    readSession: readSession,
    notifications: notifications,
    paymentReturnUrl: paymentReturnUrl,
    kyc: kyc,
    access: access,
    sessionPreferences: sessionPreferences,
    webAuthEndpoints: webAuthEndpoints,
    basicAuth: basicAuth,
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
    ExchangeAccessLifecycle? access,
    Preferences? sessionPreferences,
    ExchangeWebAuthEndpoints? webAuthEndpoints,
    ExchangeBasicAuthStore? basicAuth,
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
      _CompletionCheck completionCheck = _CompletionCheck.none,
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
            // A committed write remains successful even if the session
            // changes before its response arrives.
            if (completionCheck == _CompletionCheck.write &&
                result is Ok<T, ExchangeFailure>) {
              return result;
            }
            if (stale) return const Err(ExchangeOperationStaleFailure());
            if (completionCheck != _CompletionCheck.none) {
              switch (await sessionSnapshot()) {
                case Ok(value: final current) when current == value:
                  break;
                case _:
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
          completionCheck: _CompletionCheck.read,
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
              completionCheck: _CompletionCheck.write,
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
                  completionCheck: _CompletionCheck.write,
                ),
      ),
      (environment) => BbxApiOrderRepository(
        isTestnet: environment == ExchangeEnvironment.testnet,
        read: <T>(operation) => withClient<T>(
          (client, _) => operation(client),
          environment: environment,
          completionCheck: _CompletionCheck.read,
        ),
        write: <T>(operation) => withClient<T>(
          (client, _) => operation(client),
          environment: environment,
          completionCheck: _CompletionCheck.write,
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
        getUnreadCount: () => withClient(
          (client, _) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).getUnreadMessageCount(),
          credentialReadFailure: ExchangeChatLoadMessagesFailure.new,
        ),
        markAllRead: () => withClient(
          (client, _) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).markAllMessagesRead(),
          credentialReadFailure: ExchangeChatLoadMessagesFailure.new,
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
      kyc == null
          ? null
          : ExchangeKycConfigurationRepository(
              kyc,
              () => _loadWebPreferences(sessionPreferences, basicAuth),
            ),
      () => withClient((client, untimedClient) async {
        switch (await BbxApiUserRepository(api: client).getUserSummary()) {
          case Err():
            return const Err(ExchangeAccountUnavailableFailure());
          case Ok(:final value):
            if (!value.isEligibleForConfidentialSepa) {
              return const Ok(ConfidentialSepaAvailability.unavailable);
            }
        }
        return (await BbxApiVirtualIbanRepository(untimedClient()).find()).map(
          (iban) => iban is ActiveVirtualIban
              ? ConfidentialSepaAvailability.ready
              : ConfidentialSepaAvailability.needsVirtualIban,
        );
      }, completionCheck: _CompletionCheck.read),
      access,
      ExchangeRecipientsImpl(
        read: <T>(environment, operation) => withClient<T>(
          (client, _) => operation(client),
          environment: environment,
          untimed: true,
          completionCheck: _CompletionCheck.read,
        ),
        write: <T>(environment, operation) => withClient<T>(
          (client, _) => operation(client),
          environment: environment,
          untimed: true,
          completionCheck: _CompletionCheck.write,
        ),
      ),
      sessionPreferences,
      webAuthEndpoints,
      basicAuth,
    );
  }

  /// Applies onboarding's choice only if access has not already been set.
  @useResult
  Future<Result<void, ExchangeFailure>> applyInitialChoice(
    bool enabled,
  ) async =>
      await _access?.enable(onlyIfUnset: true, choice: enabled) ??
      const Err(ExchangeSessionClearFailure());

  ExchangeAccess get currentAccess =>
      _access?.current ?? const ExchangeAccessUnreadable();

  Stream<ExchangeAccess> watchAccess() =>
      _access?.watch() ?? Stream.value(currentAccess);

  @useResult
  Future<Result<ExchangeWebPreferences, ExchangeFailure>>
  loadWebPreferences() => _loadWebPreferences(_sessionPreferences, _basicAuth);

  static Future<Result<ExchangeWebPreferences, ExchangeFailure>>
  _loadWebPreferences(
    ActiveEnvironmentReader? environment,
    ExchangeBasicAuthStore? basicAuth,
  ) async {
    if (environment == null || basicAuth == null) {
      return const Err(ExchangeUnexpectedFailure());
    }
    return GetExchangeWebSettingsUsecase(
      environment: environment,
      basicAuth: basicAuth,
    ).execute();
  }

  /// The sandbox's Basic Auth as stored. A failed read is not an empty value.
  @useResult
  Future<Result<ExchangeBasicAuthValues, ExchangeFailure>>
  readTestnetBasicAuth() async =>
      await _basicAuth?.read() ?? const Err(ExchangeCredentialReadFailure());

  /// Replaces the sandbox's Basic Auth; a null field clears it.
  @useResult
  Future<Result<void, ExchangeFailure>> saveTestnetBasicAuth({
    String? username,
    String? password,
  }) async =>
      await _basicAuth?.save(username: username, password: password) ??
      const Err(ExchangeBasicAuthSaveFailure());

  /// Whether the active network has no Exchange service.
  Future<bool> networkUnavailable() async =>
      switch (await loadWebPreferences()) {
        Err(failure: ExchangeUnsupportedNetworkFailure()) => true,
        _ => false,
      };

  /// Decides whether a trading route may open now.
  @useResult
  Future<Result<ExchangeAvailability, ExchangeFailure>>
  guardTradingEntry() async =>
      await _access?.tradingAvailability() ??
      const Err(ExchangeAccountUnavailableFailure());

  @useResult
  Future<Result<void, ExchangeFailure>> resolveAccess() async =>
      await _access?.resolve() ?? const Err(ExchangeSessionClearFailure());

  @useResult
  Future<Result<void, ExchangeFailure>> enableAccess({
    bool forSupport = false,
  }) async =>
      await _access?.enable(forSupport: forSupport) ??
      const Err(ExchangeSessionClearFailure());

  /// Completes one WebView authentication. The session owner checks the
  /// active environment and the view lifetime before saving a credential.
  @useResult
  Future<Result<void, ExchangeFailure>> authenticateWebSession({
    required bool isTestnet,
    required bool Function() isCurrent,
    required Future<Object> Function(String) evaluateJavaScript,
  }) async {
    final access = _access;
    final endpoints = _webAuthEndpoints;
    if (access == null || endpoints == null) {
      return const Err(ExchangeAuthenticationFailure());
    }
    return CompleteExchangeAuthenticationUsecase(
      authRepository: ExchangeAuthRepositoryImpl(
        datasource: ExchangeWebAuthDatasource(
          signInUrl: isTestnet ? endpoints.testnet : endpoints.mainnet,
          evaluateJavaScript: evaluateJavaScript,
          isOpen: isCurrent,
        ),
      ),
      access: access,
      isTestnet: isTestnet,
    ).execute(isCurrent: isCurrent);
  }

  /// Loads the foreground account and expires only a rejected current session.
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> loadCurrentAccount() async {
    final access = _access;
    final preferences = _sessionPreferences;
    if (access == null || preferences == null) {
      return const Err(ExchangeAccountUnavailableFailure());
    }
    return GetExchangeAccountUsecase(
      exchange: this,
      settingsRepository: preferences,
      access: access,
      expire: ExpireExchangeSessionUsecase(access),
    ).execute();
  }

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>>
  loadCurrentAnnouncements() async {
    final access = _access;
    final preferences = _sessionPreferences;
    if (access == null || preferences == null) {
      return const Err(ExchangeAnnouncementsUnavailableFailure());
    }
    return GetExchangeAnnouncementsUsecase(
      exchange: this,
      settingsRepository: preferences,
      access: access,
    ).execute();
  }

  /// Merges partial updates with a fresh account summary before saving.
  @useResult
  Future<Result<void, ExchangeFailure>> updateCurrentPreferences({
    String? language,
    String? currency,
    bool? emailNotificationsEnabled,
    bool? dcaEnabled,
    String? autoBuyEnabled,
  }) async {
    final access = _access;
    final preferences = _sessionPreferences;
    if (access == null || preferences == null) {
      return const Err(ExchangePreferencesSaveFailure());
    }
    return SaveExchangePreferencesUsecase(
      exchange: this,
      settingsRepository: preferences,
      access: access,
    ).execute(
      language: language,
      currency: currency,
      emailNotificationsEnabled: emailNotificationsEnabled,
      dcaEnabled: dcaEnabled,
      autoBuyEnabled: autoBuyEnabled,
    );
  }

  WatchExchangeNotificationsUsecase? get _currentNotifications {
    final access = _access;
    final preferences = _sessionPreferences;
    return access == null || preferences == null
        ? null
        : WatchExchangeNotificationsUsecase(
            exchange: this,
            settingsRepository: preferences,
            access: access,
          );
  }

  Stream<NotificationMessage> watchAccountChanges() =>
      _currentNotifications?.accountChanges() ?? const Stream.empty();

  Stream<NotificationMessage> watchSupportMessages() =>
      _currentNotifications?.supportMessages() ?? const Stream.empty();

  @useResult
  Future<Result<int, ExchangeFailure>>
  loadCurrentUnreadSupportMessageCount() async {
    final access = _access;
    if (access == null) return const Err(ExchangeNotAuthenticatedFailure());
    return GetUnreadSupportMessageCountUsecase(
      exchange: this,
      access: access,
    ).execute();
  }

  @useResult
  Future<Result<void, ExchangeFailure>> markCurrentSupportMessagesRead() async {
    final access = _access;
    if (access == null) return const Err(ExchangeNotAuthenticatedFailure());
    return MarkSupportMessagesReadUsecase(
      exchange: this,
      access: access,
    ).execute();
  }

  @useResult
  Future<Result<void, ExchangeFailure>> openCurrentNotifications({
    bool reconnect = false,
  }) async {
    final notifications = _currentNotifications;
    if (notifications == null) {
      return const Err(ExchangeNotificationsUnavailableFailure());
    }
    return reconnect ? notifications.reconnect() : notifications.connect();
  }

  @useResult
  Future<Result<void, ExchangeFailure>> signOut() async =>
      await _access?.signOut() ?? const Err(ExchangeSessionClearFailure());

  /// Sends the account deletion request to support, then signs out only if
  /// the account still belongs to the session that sent it.
  @useResult
  Future<Result<ExchangeAccountDeletionOutcome, ExchangeFailure>>
  deleteAccount() async {
    final access = _access;
    if (access == null) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final current = access.current;
    if (current is! ExchangeAccessEnabled ||
        current.session != ExchangeAccessSession.signedIn) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final epoch = access.epoch;
    final result = await sendSupportMessage(
      text: 'I want to delete my account',
    );
    if (access.epoch != epoch) {
      return const Ok(ExchangeAccountDeletionOutcome.stale);
    }
    if (result case Err(:final failure)) {
      return Err(switch (failure) {
        ExchangeUnsupportedNetworkFailure() => failure,
        _ => ExchangeAccountDeletionRequestFailure(
          'sendSupportChatMessage failed: ${failure.runtimeType}',
        ),
      });
    }
    return (await access.signOut()).map(
      (_) => ExchangeAccountDeletionOutcome.completed,
    );
  }

  /// Returns false only after scanning a complete, stable session inventory.
  /// A signed-out account cannot establish absence.
  @useResult
  Future<Result<bool, ExchangeFailure>> hasPendingOrders() =>
      _hasPendingOrders();

  @useResult
  Future<Result<OrderStatistics, ExchangeFailure>> getOrderStats() =>
      _getOrderStats();

  @useResult
  Future<Result<ExchangeKycConfiguration, ExchangeFailure>> loadKyc() async =>
      await _kyc?.load() ?? const Err(ExchangeUnexpectedFailure());

  @useResult
  Future<Result<void, ExchangeFailure>> uploadKycDocument({
    required List<int> fileBytes,
    required String fileName,
  }) => _uploadKycDocument(fileBytes: fileBytes, fileName: fileName);

  /// Reads the account, distinguishing an HTTP 401 from an absent local key.
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> getAccount(
    ExchangeEnvironment environment,
  ) => _getAccount(environment);

  /// Reads the summary with the historical account-availability semantics.
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> getUserSummary([
    ExchangeEnvironment? environment,
  ]) => _getUserSummary(environment);

  /// Checks account eligibility and then the IBAN under one session. A failed
  /// lookup is distinct from an eligible account without an active IBAN.
  @useResult
  Future<Result<ConfidentialSepaAvailability, ExchangeFailure>>
  getConfidentialSepaAvailability() => _getConfidentialSepaAvailability();

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>> listAnnouncements(
    ExchangeEnvironment environment,
  ) => _listAnnouncements(environment);

  /// Replaces the account's preference set. Supply all existing values that
  /// should be retained when changing only one field.
  @useResult
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

  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeFailure>> getSupportMessages({
    int? page,
    int? pageSize,
  }) => _chat.getMessages(page: page, pageSize: pageSize);

  @useResult
  Future<Result<void, ExchangeFailure>> sendSupportMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) => _chat.sendMessage(text: text, attachments: attachments);

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeFailure>>
  getSupportAttachment(String attachmentId) =>
      _chat.getAttachment(attachmentId);

  /// The number of support messages the user has not read.
  @useResult
  Future<Result<int, ExchangeFailure>> getUnreadSupportMessageCount() =>
      _chat.getUnreadCount();

  @useResult
  Future<Result<void, ExchangeFailure>> markSupportMessagesRead() =>
      _chat.markAllRead();

  /// Broadcasts messages and recoverable failures from the active socket.
  /// An [Err] does not close the stream. Failures before opening a socket
  /// (such as an unavailable environment) are returned by the command only.
  Stream<Result<NotificationMessage, ExchangeFailure>> get notifications =>
      _notifications.messages();

  @useResult
  Future<Result<void, ExchangeFailure>> connectNotifications() =>
      _notifications.connect();

  @useResult
  Future<Result<void, ExchangeFailure>> reconnectNotifications() =>
      _notifications.reconnect();

  void disconnectNotifications() => _notifications.disconnect();

  Future<void> close() => _notifications.close();
}

/// Builds the public capability with scenario-controlled results.
Exchange exchangeForTesting({
  Future<Result<bool, ExchangeFailure>> Function()? hasPendingOrders,
  Future<Result<OrderStatistics, ExchangeFailure>> Function()? getOrderStats,
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
  Future<Result<ConfidentialSepaAvailability, ExchangeFailure>> Function()?
  getConfidentialSepaAvailability,
  ExchangeRecipients? recipients,
  ExchangeAccessLifecycle? access,
  Preferences? sessionPreferences,
  ExchangeBasicAuthStore? basicAuth,
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
        getUnreadCount: () =>
            throw StateError('Unexpected chat unread count request'),
        markAllRead: () => throw StateError('Unexpected chat mark read'),
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
  null,
  getConfidentialSepaAvailability ??
      () => throw StateError('Unexpected Confidential SEPA availability check'),
  access,
  recipients ??
      ExchangeRecipientsImpl(
        read: <T>(_, _) => throw StateError('Unexpected fiat recipient read'),
        write: <T>(_, _) => throw StateError('Unexpected fiat recipient write'),
      ),
  sessionPreferences,
  null,
  basicAuth,
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
