import 'dart:async';

import 'package:bbx_api/bbx_api.dart'
    show Bbx, BbxCredentialUnavailableFailure, BbxTimeouts;
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';

import 'data/bbx_api_account_repository.dart';
import 'data/bbx_api_exchange_recipient_repository.dart';
import 'data/bbx_api_funding_rails.dart';
import 'data/bbx_api_kyc_repository.dart';
import 'data/bbx_api_limit_order_repository.dart';
import 'data/bbx_api_notification_datasource.dart';
import 'data/bbx_api_order_stats_repository.dart';
import 'data/bbx_api_order_repository.dart';
import 'data/bbx_api_support_chat_repository.dart';
import 'data/bbx_api_user_repository.dart';
import 'data/bbx_api_virtual_iban_repository.dart';
import 'data/exchange_call_classifier.dart';
import 'data/exchange_notification_service.dart';
import 'data/exchange_kyc_configuration_repository.dart';
import 'data/journaling_exchange_orders.dart';
import 'data/journaling_exchange_recipients.dart';
import 'data/pending_orders.dart';
import 'domain/entities/announcement.dart';
import 'domain/entities/btc_network.dart';
import 'domain/entities/confidential_sepa_availability.dart';
import 'domain/entities/default_wallet.dart';
import 'domain/entities/limit_order.dart';
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
import 'domain/exchange_call_result.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';
import 'domain/exchange_funding.dart';
import 'domain/exchange_kyc_configuration.dart';
import 'domain/exchange_limit_orders.dart';
import 'domain/exchange_orders.dart';
import 'domain/exchange_virtual_ibans.dart';
import 'domain/exchange_write_gate.dart';
import 'domain/order_create_journal.dart';
import 'domain/unknown_write_journal.dart';
import 'setup/exchange_access_lifecycle.dart';
import 'recipients/exchange_recipients.dart';
import 'session/complete_exchange_authentication_usecase.dart';
import 'session/exchange_auth_repository_impl.dart';
import 'session/exchange_web_auth_datasource.dart';
import 'session/expire_exchange_session_usecase.dart';
import 'session/get_exchange_account_usecase.dart';
import 'session/get_exchange_announcements_usecase.dart';
import 'session/get_exchange_web_settings_usecase.dart';
import 'session/reconcile_unknown_writes_usecase.dart';
import 'session/update_exchange_preferences.dart';
import 'domain/exchange_preferences_patch.dart';
import 'session/watch_exchange_activation_offer.dart';
import 'session/watch_exchange_notifications_usecase.dart';
import 'session/watch_exchange_trading_visibility.dart';

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
  Future<ExchangeWrite<DefaultWallet>> Function({
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  })
  save,
  Future<ExchangeWrite<void>> Function({
    required String recipientId,
    required BtcNetwork walletType,
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
  Future<ExchangeRead<int>> Function(ExchangeSession) getUnreadCount,
  Future<ExchangeWrite<void>> Function(ExchangeSession) markAllRead,
});

typedef ExchangeNotificationBindings = ({
  Future<Result<String?, Failure>> Function({required bool isTestnet}) readKey,
});

typedef ExchangeNotificationOperations = ({
  Stream<Result<NotificationMessage, ExchangeFailure>> Function() messages,
  Future<Result<void, ExchangeFailure>> Function(ExchangeEnvironment) connect,
  Future<Result<void, ExchangeFailure>> Function(ExchangeEnvironment) reconnect,
  void Function() disconnect,
  Future<void> Function() close,
});

typedef ExchangeWebAuthEndpoints = ({Uri mainnet, Uri testnet});

enum _CompletionCheck { none, read, write }

typedef _SessionPoint = ({ExchangeEnvironment environment, int epoch});

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
  final UnknownWriteJournal? _unknownWrites;
  final Future<Result<_SessionPoint, ExchangeFailure>> Function()
  _readSessionPoint;

  /// One financial write at a time per account, shared by every flow.
  final ExchangeWriteGate writeGate;

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
    this._unknownWrites,
    this._readSessionPoint,
    this.writeGate,
  );

  /// Opens the capability without doing I/O. [readSession] must return an
  /// authoritative snapshot of the current session; its epoch must change when
  /// the environment or access changes, even if the same key is later reused.
  /// The credential is never published by an Exchange operation.
  ///
  /// TODO(exchange): the app opens the exchange without [unknownWrites]: the
  /// journal is inactive until the storage cutover mounts the exchange
  /// database at runtime (`DriftUnknownWriteJournal` over its
  /// `ExchangeDatabase`). Without it nothing is journaled, reconciling is a
  /// no-op and [writeGate] only tracks writes in flight.
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
    UnknownWriteJournal? unknownWrites,
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
    unknownWrites: unknownWrites,
    openClient: (endpoint, readKey) => Bbx.open(
      endpoint: endpoint.toString(),
      readActiveApiKey: readKey,
      timeouts: BbxTimeouts.standard,
    ),
  );

  static Exchange _open({
    required Uri mainnetEndpoint,
    required Uri testnetEndpoint,
    required ExchangeSessionReader readSession,
    required OpenInventoryClient openClient,
    ExchangeNotificationBindings? notifications,
    Uri? paymentReturnUrl,
    ExchangeKycSetup? kyc,
    ExchangeAccessLifecycle? access,
    Preferences? sessionPreferences,
    ExchangeWebAuthEndpoints? webAuthEndpoints,
    ExchangeBasicAuthStore? basicAuth,
    UnknownWriteJournal? unknownWrites,
  }) {
    final recorder = unknownWrites == null
        ? null
        : UnknownWriteRecorder(unknownWrites);
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
      Future<Result<T, ExchangeFailure>> Function(Bbx) operation, {
      ExchangeEnvironment? environment,
      ExchangeFailure Function()? credentialReadFailure,
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
          final client = openClient(value.endpoint, readKey);
          try {
            final result = await operation(client);
            // A committed write remains successful even if the session
            // changes before its response arrives. An unknown recipient save
            // also belongs to the session that sent it: it may have committed,
            // so a session change must not turn it back into a retryable save.
            if (completionCheck == _CompletionCheck.write &&
                (result is Ok<T, ExchangeFailure> ||
                    (result is Err<T, ExchangeFailure> &&
                        result.failure
                            is RecipientsSaveOutcomeUnknownFailure))) {
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
            // A 401 to a key of this session means the key is no longer
            // valid, whatever call got it: expire that session. The access
            // lifecycle ignores an epoch that has already ended.
            if (access != null && client.sessionRejected) {
              unawaited(
                ExpireExchangeSessionUsecase(access).execute(
                  epoch: value.epoch,
                  isTestnet: value.environment == ExchangeEnvironment.testnet,
                ),
              );
            }
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
      (client) => call(BbxApiLimitOrderRepository(client)),
      credentialReadFailure: () =>
          ExchangeLimitOrderFailure(problem, 'Exchange credential unavailable'),
    );
    final fundingReturnUrl =
        paymentReturnUrl ?? Uri.parse('https://app.bullbitcoin.com');
    Future<ExchangeRead<T>> fundRead<T>(
      ExchangeSession session,
      Future<ExchangeRead<T>> Function(BbxApiFundingRails) call,
    ) async => switch (await withClient<ExchangeRead<T>>(
      (client) async => Ok(
        await call(
          BbxApiFundingRails(client, paymentReturnUrl: fundingReturnUrl),
        ),
      ),
      environment: session.environment,
      completionCheck: _CompletionCheck.read,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => readOfFailure<T>(failure),
    };
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

      // The epoch is read before each key read, so a refused handshake
      // expires only the session whose key it carried.
      BbxApiNotificationDatasource datasource(Uri endpoint, bool isTestnet) {
        int? keyEpoch;
        return BbxApiNotificationDatasource(
          baseUrl: endpoint.toString(),
          readApiKey: () {
            keyEpoch = access?.session?.epoch;
            return readKey(isTestnet);
          },
          onSessionRejected: () {
            final epoch = keyEpoch;
            if (access == null || epoch == null) return;
            unawaited(
              ExpireExchangeSessionUsecase(access)
                  .execute(epoch: epoch, isTestnet: isTestnet),
            );
          },
        );
      }

      return notificationService ??= ExchangeNotificationService(
        mainnetDatasource: datasource(mainnetEndpoint, false),
        testnetDatasource: datasource(testnetEndpoint, true),
      );
    }

    return Exchange._(
      inventory.hasPendingOrders,
      () => withClient(
        (client) => BbxApiOrderStatsRepository(api: client).getOrderStats(),
      ),
      ({required fileBytes, required fileName}) => withClient(
        (client) => BbxApiKycRepository(api: client).uploadDocument(
          fileBytes: fileBytes,
          fileName: fileName,
          docType: 'ID',
          sourceDetail: 'SECURE_UPLOAD',
        ),
      ),
      (environment) => withClient(
        (client) => BbxApiAccountRepository(client).getAccount(),
        environment: environment,
        credentialReadFailure: ExchangeAccountUnavailableFailure.new,
      ),
      (environment) => withClient(
        (client) => BbxApiUserRepository(api: client).getUserSummary(),
        environment: environment,
      ),
      (environment) => withClient(
        (client) => BbxApiUserRepository(api: client).listAnnouncements(),
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
        (client) => BbxApiUserRepository(api: client).saveUserPreference(
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
          (client) =>
              BbxApiExchangeRecipientRepository(api: client)
                  .getDefaultWallets(),
          completionCheck: _CompletionCheck.read,
        ),
        save:
            ({
              required walletType,
              required address,
              existingRecipientId,
            }) async => switch (await withClient<ExchangeWrite<DefaultWallet>>(
              (client) async => Ok(
                await BbxApiExchangeRecipientRepository(api: client)
                    .saveDefaultWallet(
                      walletType: walletType,
                      address: address,
                      existingRecipientId: existingRecipientId,
                    ),
              ),
              completionCheck: _CompletionCheck.write,
            )) {
              Ok(:final value) => value,
              Err(:final failure) => writeNotRun(failure),
            },
        delete:
            ({
              required recipientId,
              required walletType,
              required address,
            }) async => switch (await withClient<ExchangeWrite<void>>(
              (client) async => Ok(
                await BbxApiExchangeRecipientRepository(api: client)
                    .deleteDefaultWallet(
                      recipientId: recipientId,
                      walletType: walletType,
                      address: address,
                    ),
              ),
              completionCheck: _CompletionCheck.write,
            )) {
              Ok(:final value) => value,
              Err(:final failure) => writeNotRun(failure),
            },
      ),
      (environment) => BbxApiOrderRepository(
        isTestnet: environment == ExchangeEnvironment.testnet,
        read: <T>(operation) => withClient<T>(
          (client) => operation(client),
          environment: environment,
          completionCheck: _CompletionCheck.read,
        ),
        write: <T>(operation) => withClient<T>(
          (client) => operation(client),
          environment: environment,
          completionCheck: _CompletionCheck.write,
        ),
      ),
      (
        getMessages: ({page, pageSize}) => withClient(
          (client) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).getMessages(page: page, pageSize: pageSize),
          credentialReadFailure: ExchangeChatLoadMessagesFailure.new,
        ),
        sendMessage: ({required text, attachments}) => withClient(
          (client) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).sendMessage(text: text, attachments: attachments),
          credentialReadFailure: ExchangeChatSendMessageFailure.new,
        ),
        getAttachment: (attachmentId) => withClient(
          (client) => BbxApiSupportChatRepository(
            users: client.users,
            commcenter: client.commcenter,
          ).getMessageAttachment(attachmentId),
          credentialReadFailure: ExchangeChatLoadAttachmentFailure.new,
        ),
        getUnreadCount: (session) async =>
            switch (await withClient<ExchangeRead<int>>(
              (client) async => Ok(
                await BbxApiSupportChatRepository(
                  users: client.users,
                  commcenter: client.commcenter,
                ).readUnreadMessageCount(),
              ),
              environment: session.environment,
              completionCheck: _CompletionCheck.read,
            )) {
              Ok(:final value) => value,
              Err(:final failure) => readNotRun(failure),
            },
        markAllRead: (session) async =>
            switch (await withClient<ExchangeWrite<void>>(
              (client) async => Ok(
                await BbxApiSupportChatRepository(
                  users: client.users,
                  commcenter: client.commcenter,
                ).markAllMessagesRead(),
              ),
              environment: session.environment,
            )) {
              Ok(:final value) => value,
              Err(:final failure) => writeNotRun(failure),
            },
      ),
      (
        messages: () => service().messageStream,
        connect: (environment) => service().connect(environment),
        reconnect: (environment) => service().reconnect(environment),
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
        listRecent: () => limitOrder(
          ExchangeLimitOrderProblem.load,
          (repository) => repository.listRecent(),
        ),
        get: (id) => limitOrder(
          ExchangeLimitOrderProblem.load,
          (repository) => repository.get(id),
        ),
        create: (draft) async {
          final write = switch (await withClient<ExchangeWrite<LimitOrder>>(
            (client) async =>
                Ok(await BbxApiLimitOrderRepository(client).create(draft)),
            completionCheck: _CompletionCheck.write,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => writeNotRun<LimitOrder>(failure),
          };
          if (write is WriteOutcomeUnknown<LimitOrder> && recorder != null) {
            if (await sessionSnapshot() case Ok(:final value)) {
              await recorder.record(
                UnknownWriteDraft(
                  kind: UnknownWriteKind.limitOrderCreate,
                  environment: value.environment,
                  sessionEpoch: value.epoch,
                  request: draft.journalRequest,
                ),
              );
            }
          }
          return write;
        },
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
        account: (session) => fundRead(session, (rails) => rails.account()),
        instructions: (session, request) =>
            fundRead(session, (rails) => rails.instructions(request)),
        institutions: (session, jurisdiction) =>
            fundRead(session, (rails) => rails.institutions(jurisdiction)),
        consent: (session) async =>
            switch (await withClient<ExchangeWrite<void>>(
              (client) async => Ok(
                await BbxApiFundingRails(
                  client,
                  paymentReturnUrl: fundingReturnUrl,
                ).consent(),
              ),
              environment: session.environment,
              completionCheck: _CompletionCheck.write,
            )) {
              Ok(:final value) => value,
              Err(:final failure) => writeNotRun<void>(failure),
            },
        consentOnAccount: (session) =>
            fundRead(session, (rails) => rails.consentOnAccount()),
      ),
      ExchangeVirtualIbansImpl(
        find: (environment) => withClient(
          (client) => BbxApiVirtualIbanRepository(client).find(),
          environment: environment,
        ),
        create: (environment) => withClient(
          (client) => BbxApiVirtualIbanRepository(client).create(),
          environment: environment,
        ),
      ),
      kyc == null
          ? null
          : ExchangeKycConfigurationRepository(
              kyc,
              () => _loadWebPreferences(sessionPreferences, basicAuth),
            ),
      () => withClient((client) async {
        switch (await BbxApiUserRepository(api: client).getUserSummary()) {
          case Err():
            return const Err(ExchangeAccountUnavailableFailure());
          case Ok(:final value):
            if (!value.isEligibleForConfidentialSepa) {
              return const Ok(ConfidentialSepaAvailability.unavailable);
            }
        }
        return (await BbxApiVirtualIbanRepository(client).find()).map(
          (iban) => iban is ActiveVirtualIban
              ? ConfidentialSepaAvailability.ready
              : ConfidentialSepaAvailability.needsVirtualIban,
        );
      }, completionCheck: _CompletionCheck.read),
      access,
      _journalRecipients(
        ExchangeRecipientsImpl(
          read: <T>(environment, operation) => withClient<T>(
            (client) => operation(client),
            environment: environment,
            completionCheck: _CompletionCheck.read,
          ),
          write: <T>(environment, operation) => withClient<T>(
            (client) => operation(client),
            environment: environment,
            completionCheck: _CompletionCheck.write,
          ),
        ),
        recorder,
        () async => (await sessionSnapshot()).map(
          (s) => (environment: s.environment, epoch: s.epoch),
        ),
      ),
      sessionPreferences,
      webAuthEndpoints,
      basicAuth,
      unknownWrites,
      () async => (await sessionSnapshot()).map(
        (s) => (environment: s.environment, epoch: s.epoch),
      ),
      ExchangeWriteGate(journal: unknownWrites),
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

  /// Whether a signed-in user can trade on the current platform and network.
  Stream<bool> watchTradingVisibility({
    required ExchangePlatform platform,
    required Stream<bool> superuserChanges,
  }) => observeExchangeTradingVisibility(
    platform: platform,
    superuserChanges: superuserChanges,
    preferences: _sessionPreferences,
    currentAccess: () => currentAccess,
    watchAccess: watchAccess,
    networkUnavailable: networkUnavailable,
  );

  /// Whether the Exchange entry is available, or only the activation offer
  /// when [onlyWhileOff] is true.
  Stream<bool> watchActivationOffer({
    required ExchangePlatform platform,
    required bool Function() currentSuperuser,
    required Stream<bool> superuserChanges,
    required bool onlyWhileOff,
  }) => observeExchangeActivationOffer(
    platform: platform,
    currentSuperuser: currentSuperuser,
    superuserChanges: superuserChanges,
    onlyWhileOff: onlyWhileOff,
    currentAccess: () => currentAccess,
    watchAccess: watchAccess,
    networkUnavailable: networkUnavailable,
  );

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

  /// Loads the account of [session]; see [GetExchangeAccountUsecase].
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> loadAccount(
    ExchangeSession session,
  ) async {
    final access = _access;
    if (access == null) return const Err(ExchangeAccountUnavailableFailure());
    return GetExchangeAccountUsecase(
      exchange: this,
      access: access,
      expire: ExpireExchangeSessionUsecase(access),
    ).execute(session);
  }

  /// [loadAccount] for the session signed in now.
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> loadCurrentAccount() async =>
      switch (_access?.session) {
        null => const Err(ExchangeNotAuthenticatedFailure()),
        final session => loadAccount(session),
      };

  @useResult
  Future<Result<List<Announcement>, ExchangeFailure>> loadAnnouncements(
    ExchangeSession session,
  ) async {
    final access = _access;
    if (access == null) {
      return const Err(ExchangeAnnouncementsUnavailableFailure());
    }
    return GetExchangeAnnouncementsUsecase(
      exchange: this,
      access: access,
    ).execute(session);
  }

  /// The current session, when signed in.
  ExchangeSession? get currentSession => _access?.session;

  /// Changes the fields of [patch] that differ from the account of
  /// [session]; see [UpdateExchangePreferences]. This is the only way the
  /// app writes account preferences.
  @useResult
  Future<Result<void, ExchangeFailure>> updatePreferences(
    ExchangeSession session,
    ExchangePreferencesPatch patch,
  ) => UpdateExchangePreferences(
    readSummary: getUserSummary,
    write: saveUserPreference,
    currentSession: () => _access?.session,
  ).execute(session, patch);

  /// [updatePreferences] for the session signed in now.
  @useResult
  Future<Result<void, ExchangeFailure>> updateCurrentPreferences(
    ExchangePreferencesPatch patch,
  ) async => switch (_access?.session) {
    null => const Err(ExchangeNotAuthenticatedFailure()),
    final session => updatePreferences(session, patch),
  };

  WatchExchangeNotificationsUsecase? get _currentNotifications {
    final access = _access;
    final preferences = _sessionPreferences;
    return access == null || preferences == null
        ? null
        : WatchExchangeNotificationsUsecase(exchange: this);
  }

  Stream<NotificationMessage> watchAccountChanges() =>
      _currentNotifications?.accountChanges() ?? const Stream.empty();

  /// Emits whenever the server says the support chat has a new message.
  Stream<NotificationMessage> watchSupportMessages() =>
      _currentNotifications?.supportMessages() ?? const Stream.empty();

  /// Reopens the current session's socket after the app comes back; the
  /// platform may have dropped it while hidden. Nothing while signed out:
  /// the socket belongs to the signed-in state.
  Future<void> reconnectCurrentNotifications() async {
    await _access?.reconnectNotifications();
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
    final session = access.session;
    if (session == null) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }
    final result = await sendSupportMessage(
      text: 'I want to delete my account',
    );
    if (access.session != session) {
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

  /// Replaces the account's preference set: the wire call under
  /// [updatePreferences], which is what callers use.
  /// With a journal, a save whose outcome is unknown is recorded (the fields
  /// sent) before it is returned.
  @useResult
  Future<Result<void, ExchangeFailure>> saveUserPreference(
    ExchangeEnvironment environment, {
    String? language,
    String? currency,
    bool? dcaEnabled,
    String? autoBuyEnabled,
    bool? emailNotificationsEnabled,
  }) async {
    final result = await _saveUserPreference(
      environment,
      language: language,
      currency: currency,
      dcaEnabled: dcaEnabled,
      autoBuyEnabled: autoBuyEnabled,
      emailNotificationsEnabled: emailNotificationsEnabled,
    );
    final journal = _unknownWrites;
    if (journal == null ||
        result is! Err<void, ExchangeFailure> ||
        result.failure is! ExchangePreferencesSaveOutcomeUnknownFailure) {
      return result;
    }
    await UnknownWriteRecorder(journal).record(
      UnknownWriteDraft(
        kind: UnknownWriteKind.preferencesSave,
        environment: environment,
        sessionEpoch: await _epochOf(environment),
        request: {
          'language': ?language,
          'currency': ?currency,
          'dcaEnabled': ?dcaEnabled?.toString(),
          'autoBuyEnabled': ?autoBuyEnabled,
          'emailNotificationsEnabled': ?emailNotificationsEnabled?.toString(),
        },
      ),
    );
    return result;
  }

  /// Records an order create of [session] whose outcome is unknown
  /// (`runOrderCreate`'s `journalUnknown`), so reconcile can match it against
  /// the recent orders. Nothing happens without a journal.
  Future<void> journalUnknownOrderCreate(
    ExchangeSession session,
    OrderCreateJournalRequest request,
  ) async {
    final journal = _unknownWrites;
    if (journal == null) return;
    await UnknownWriteRecorder(journal).record(
      UnknownWriteDraft(
        kind: UnknownWriteKind.orderCreate,
        environment: session.environment,
        sessionEpoch: session.epoch,
        request: request.toRequest(),
      ),
    );
  }

  /// Records a sell or pay payin of [session] whose broadcast outcome is
  /// unknown (`runPayinBroadcast`'s `journalUnknown`), before the flow moves
  /// to verifying it. Until a re-read of [orderId] settles it, the entry
  /// holds the write gate. Nothing happens without a journal.
  Future<void> journalUnknownPayin(
    ExchangeSession session, {
    required String orderId,
    required BtcNetwork network,
    String? txid,
  }) async {
    final journal = _unknownWrites;
    if (journal == null) return;
    await UnknownWriteRecorder(journal).record(
      UnknownWriteDraft(
        kind: UnknownWriteKind.payin,
        environment: session.environment,
        sessionEpoch: session.epoch,
        orderId: orderId,
        request: {'orderId': orderId, 'network': network.name, 'txid': ?txid},
      ),
    );
  }

  Future<int?> _epochOf(ExchangeEnvironment environment) async =>
      switch (await _readSessionPoint()) {
        Ok(:final value) when value.environment == environment => value.epoch,
        _ => null,
      };

  /// Binds operations to the caller's selected backend, not to a credential.
  /// Every request checks that the active session still matches that backend.
  ///
  /// With a journal, a confirm, accelerate or DCA create whose outcome is
  /// unknown is recorded before its result is returned.
  ExchangeOrders orders(ExchangeEnvironment environment) =>
      switch (_unknownWrites) {
        final journal? => JournalingExchangeOrders(
          _orders(environment),
          UnknownWriteRecorder(journal),
          environment: environment,
          readEpoch: () => _epochOf(environment),
        ),
        null => _orders(environment),
      };

  @useResult
  Future<Result<DefaultWallets, ExchangeFailure>> getDefaultWallets() =>
      _defaultWallets.get();

  /// The open journal entries of the current session's environment: writes
  /// that may have reached the exchange and are not settled yet. Empty
  /// without a journal.
  @useResult
  Future<Result<List<UnknownWrite>, Failure>> openUnknownWrites() async {
    final journal = _unknownWrites;
    if (journal == null) return const Ok([]);
    return switch (await _readSessionPoint()) {
      Ok(:final value) => await journal.open(value.environment),
      Err(:final failure) => Err(failure),
    };
  }

  /// Re-reads what each open journal entry of the current environment would
  /// have changed and settles the entries the re-read decides. Never sends a
  /// write again. Nothing to do without a journal.
  @useResult
  Future<Result<UnknownWriteReconciliation, Failure>>
  reconcileUnknownWrites() async {
    final journal = _unknownWrites;
    if (journal == null) {
      return const Ok(UnknownWriteReconciliation(settled: 0, open: 0));
    }
    switch (await _readSessionPoint()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return ReconcileUnknownWritesUsecase(
          journal: journal,
          orders: _orders,
          getUserSummary: (environment) => _getUserSummary(environment),
          listRecentLimitOrders: limitOrders.listRecent,
          getDefaultWallets: _defaultWallets.get,
          recipients: recipients,
        ).execute(value.environment);
    }
  }

  /// [WriteOutcomeUnknown] means the default wallet may be saved: re-read the
  /// default wallets before saving again.
  /// With a journal, an unknown outcome is recorded before it is returned.
  @useResult
  Future<ExchangeWrite<DefaultWallet>> saveDefaultWallet({
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    final write = await _defaultWallets.save(
      walletType: walletType,
      address: address,
      existingRecipientId: existingRecipientId,
    );
    final journal = _unknownWrites;
    if (journal == null || write is! WriteOutcomeUnknown<DefaultWallet>) {
      return write;
    }
    if (await _readSessionPoint() case Ok(:final value)) {
      await UnknownWriteRecorder(journal).record(
        UnknownWriteDraft(
          kind: UnknownWriteKind.defaultWalletSave,
          environment: value.environment,
          sessionEpoch: value.epoch,
          request: {
            'walletType': walletType.name,
            'address': address,
            'existingRecipientId': ?existingRecipientId,
          },
        ),
      );
    }
    return write;
  }

  /// [WriteOutcomeUnknown] means the default flag may be unset: re-read the
  /// default wallets before unsetting again.
  @useResult
  Future<ExchangeWrite<void>> deleteDefaultWallet({
    required String recipientId,
    required BtcNetwork walletType,
    required String address,
  }) => _defaultWallets.delete(
    recipientId: recipientId,
    walletType: walletType,
    address: address,
  );

  /// The default wallets of [session]'s account. A read for a session that
  /// is no longer the current one is never sent
  /// ([ExchangeSessionRejection.sessionChanged]).
  @useResult
  Future<ExchangeRead<DefaultWallets>> readDefaultWallets(
    ExchangeSession session,
  ) async {
    if (_access?.session != session) {
      return const ReadSessionRejected(ExchangeSessionRejection.sessionChanged);
    }
    return switch (await _defaultWallets.get()) {
      Ok(:final value) => ReadGot(value),
      Err(:final failure) => readNotRun(failure),
    };
  }

  /// Saves a default wallet of [session]'s account through [writeGate]
  /// ([FinancialWriteKind.defaultWalletSave]), so it never runs next to
  /// another financial write of that account or over an unsettled one.
  @useResult
  Future<GatedWrite<ExchangeWrite<DefaultWallet>>> saveSessionDefaultWallet(
    ExchangeSession session, {
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  }) => writeGate.run(
    session,
    FinancialWriteKind.defaultWalletSave,
    () async => _access?.session != session
        ? const WriteNotSent(ExchangeNotSentReason.sessionChanged)
        : await saveDefaultWallet(
            walletType: walletType,
            address: address,
            existingRecipientId: existingRecipientId,
          ),
  );

  /// Unsets a default wallet of [session]'s account through [writeGate]
  /// ([FinancialWriteKind.defaultWalletUnset]).
  @useResult
  Future<GatedWrite<ExchangeWrite<void>>> unsetSessionDefaultWallet(
    ExchangeSession session, {
    required String recipientId,
    required BtcNetwork walletType,
    required String address,
  }) => writeGate.run(
    session,
    FinancialWriteKind.defaultWalletUnset,
    () async => _access?.session != session
        ? const WriteNotSent(ExchangeNotSentReason.sessionChanged)
        : await deleteDefaultWallet(
            recipientId: recipientId,
            walletType: walletType,
            address: address,
          ),
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

  /// How many support messages [session]'s user has not read. A read for a
  /// session that is no longer the current one is never sent.
  @useResult
  Future<ExchangeRead<int>> readUnreadSupportCount(
    ExchangeSession session,
  ) async => _access?.session != session
      ? const ReadSessionRejected(ExchangeSessionRejection.sessionChanged)
      : await _chat.getUnreadCount(session);

  /// Marks every support message of [session]'s user as read; never sent
  /// for a session that is no longer the current one.
  @useResult
  Future<ExchangeWrite<void>> markSupportMessagesRead(
    ExchangeSession session,
  ) async => _access?.session != session
      ? const WriteNotSent(ExchangeNotSentReason.sessionChanged)
      : await _chat.markAllRead(session);

  /// Broadcasts messages and recoverable failures from the active socket.
  /// An [Err] does not close the stream. Failures before opening a socket
  /// (such as an unavailable environment) are returned by the command only.
  Stream<Result<NotificationMessage, ExchangeFailure>> get notifications =>
      _notifications.messages();

  /// Opens the socket of [environment]. The access lifecycle calls it when
  /// a session of that environment starts.
  @useResult
  Future<Result<void, ExchangeFailure>> connectNotifications(
    ExchangeEnvironment environment,
  ) => _notifications.connect(environment);

  @useResult
  Future<Result<void, ExchangeFailure>> reconnectNotifications(
    ExchangeEnvironment environment,
  ) => _notifications.reconnect(environment);

  void disconnectNotifications() => _notifications.disconnect();

  Future<void> close() => _notifications.close();
}

ExchangeRecipients _journalRecipients(
  ExchangeRecipients recipients,
  UnknownWriteRecorder? recorder,
  Future<Result<_SessionPoint, ExchangeFailure>> Function() readSessionPoint,
) => switch (recorder) {
  null => recipients,
  final recorder => JournalingExchangeRecipients(
    recipients,
    recorder,
    readEpoch: (environment) async => switch (await readSessionPoint()) {
      Ok(:final value) when value.environment == environment => value.epoch,
      _ => null,
    },
  ),
};

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
  Future<ExchangeWrite<DefaultWallet>> Function({
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  })?
  saveDefaultWallet,
  Future<ExchangeWrite<void>> Function({
    required String recipientId,
    required BtcNetwork walletType,
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
  UnknownWriteJournal? unknownWrites,
  Future<
    Result<({ExchangeEnvironment environment, int epoch}), ExchangeFailure>
  >
  Function()?
  readSessionPoint,
  ExchangeWriteGate? writeGate,
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
        getUnreadCount: (_) =>
            throw StateError('Unexpected chat unread count request'),
        markAllRead: (_) => throw StateError('Unexpected chat mark read'),
      ),
  notifications ??
      (
        messages: () => const Stream.empty(),
        connect: (_) => throw StateError('Unexpected notification connect'),
        reconnect: (_) => throw StateError('Unexpected notification reconnect'),
        disconnect: () {},
        close: () async {},
      ),
  limitOrders ??
      ExchangeLimitOrdersImpl(
        list: () => throw StateError('Unexpected limit order listing'),
        listRecent: () => throw StateError('Unexpected limit order listing'),
        get: (_) => throw StateError('Unexpected limit order read'),
        create: (_) => throw StateError('Unexpected limit order create'),
        cancel: (_) => throw StateError('Unexpected limit order cancel'),
        cancelAll: () => throw StateError('Unexpected limit order bulk cancel'),
        rate: (_) => throw StateError('Unexpected limit order rate'),
      ),
  funding ??
      ExchangeFundingImpl(
        account: (_) => throw StateError('Unexpected funding account read'),
        instructions: (_, _) =>
            throw StateError('Unexpected funding instructions request'),
        institutions: (_, _) =>
            throw StateError('Unexpected funding institution lookup'),
        consent: (_) => throw StateError('Unexpected funding consent'),
        consentOnAccount: (_) =>
            throw StateError('Unexpected funding consent re-read'),
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
  _journalRecipients(
    recipients ??
        ExchangeRecipientsImpl(
          read: <T>(_, _) => throw StateError('Unexpected fiat recipient read'),
          write: <T>(_, _) =>
              throw StateError('Unexpected fiat recipient write'),
        ),
    unknownWrites == null ? null : UnknownWriteRecorder(unknownWrites),
    readSessionPoint ?? () => throw StateError('Unexpected session read'),
  ),
  sessionPreferences,
  null,
  basicAuth,
  unknownWrites,
  readSessionPoint ?? () => throw StateError('Unexpected session read'),
  writeGate ?? ExchangeWriteGate(journal: unknownWrites),
);

Exchange exchangeWithTransportForTesting({
  required ExchangeSessionReader readSession,
  required OpenInventoryClient openClient,
  ExchangeAccessLifecycle? access,
  UnknownWriteJournal? unknownWrites,
}) => Exchange._open(
  mainnetEndpoint: Uri.parse('https://mainnet.example.invalid'),
  testnetEndpoint: Uri.parse('https://testnet.example.invalid'),
  readSession: readSession,
  openClient: openClient,
  access: access,
  unknownWrites: unknownWrites,
);
