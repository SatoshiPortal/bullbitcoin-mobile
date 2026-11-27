import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:background_tasks/background_tasks.dart';
import 'package:secrets/bip85.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/custody.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_ark/ark_foreground_maintenance_setup.dart';
import 'package:bull_ark/ark_maintenance_setup.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show SyncStorageFailure;
import 'package:secrets/secrets.dart';
import 'package:legacy_storage/coordination.dart'
    show LifecycleHandle, RuntimeAdmission;

import 'package:sync/write.dart' show WalletNativeRuntime;
import 'package:material_ui/material_ui.dart' show WidgetsBinding;

import 'ark_app_services.dart';
import 'data/ark_board_funding.dart';
import 'data/ark_exit_notification_setup.dart';

/// Constructs the wallet-owned Board actor over the runtime's single client.
typedef ArkBoardFundingFactory = ArkBoardFundingPort Function(
  ArkClient client,
  Future<String> Function(ArkAccountId account) sourceWalletId,
);

/// One Board funding binding per runtime: bound once to its client, and
/// closed after the runtime is invalidated and before its client closes.
typedef ArkBoardFundingBinding = ({
  ArkBoardFundingFactory bind,
  Future<void> Function() close,
});

/// Foreground owner of one selected Ark configuration and its native client.
///
/// Call [invalidate] before replacing the selected wallet, network or endpoint.
/// The host must await [close] before disposing the app's custody services.
final class ArkForegroundRuntime {
  final ArkFeature feature;
  final ArkClient _client;
  final LifecycleHandle? _clientHandle;
  final Future<void> Function() _closeBoardFunding;
  final _ForegroundPolicy _policy;
  final ArkForegroundMaintenance _maintenance;
  final _WalletArkSelection _selection;
  final ArkAccountConfig _config;
  final OwnedArkExitNotifier? _exitNotifier;

  /// This runtime's Board funding, which releases a stuck reservation.
  final ArkBoardFundingPort _board;
  Future<void>? _closing;
  Future<void>? _maintaining;
  Future<void>? _exiting;
  Timer? _exitPolling;

  ArkForegroundRuntime._(
    this.feature,
    this._client,
    this._clientHandle,
    this._closeBoardFunding,
    this._policy,
    this._maintenance,
    this._selection,
    this._config,
    this._board,
    this._exitNotifier,
  );

  /// The selected account this runtime was opened for.
  ArkAccountId get account => _config.id;

  Future<Result<ArkTransferContext, ArkFailure>> transferContext() async {
    if (!_policy.active) return const Err(ArkServiceUnavailableFailure());
    final selected = await _selection._select();
    if (!_policy.active) return const Err(ArkServiceUnavailableFailure());
    return switch (selected) {
      Ok(:final value)
          when value.$1.id == _config.id &&
              value.$1.arkUrl == _config.arkUrl &&
              value.$1.primaryEsploraUrl == _config.primaryEsploraUrl =>
        feature.transferContext(value.$2),
      Err(:final failure) => Err(failure),
      _ => const Err(ArkServiceUnavailableFailure()),
    };
  }

  /// Whether this runtime is open and still matches the current wallet
  /// selection. A stale runtime must be invalidated and closed by its owner.
  Future<bool> isCurrent() async {
    if (!_policy.active) return false;
    return switch (await _selection.selectedAccount()) {
          Ok(:final value) =>
            value.id == _config.id &&
                value.arkUrl == _config.arkUrl &&
                value.primaryEsploraUrl == _config.primaryEsploraUrl &&
                value.fallbackEsploraUrl == _config.fallbackEsploraUrl &&
                value.renewalThresholdBlocks == _config.renewalThresholdBlocks,
          Err() => false,
        } &&
        _policy.active;
  }

  /// Coalesce foreground resume events while a protective pass is in flight.
  Future<void> maintain() => _maintaining ??= _maintain().whenComplete(() {
    _maintaining = null;
  });

  /// Exit transactions confirm one block at a time, so while the app is open
  /// the exit lane runs every minute. Only in the foreground: a backgrounded
  /// app moves nothing.
  void _pollExits() {
    _exitPolling?.cancel();
    _exitPolling = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      unawaited(maintainExits());
    });
  }

  Future<void> maintainExits() => _exiting ??= () async {
    if (_maintaining != null || !await isCurrent()) return;
    final result = await _maintenance.runExits(_config.id);
    if (result case Err(:final failure)) {
      log.warning('Ark exit maintenance failed: ${failure.runtimeType}');
    }
    // A Board that confirms while the app is open gives its coins back now,
    // not on the next resume. Nothing pending: a local read, nothing more.
    await _reconcileBoard();
  }().whenComplete(() => _exiting = null);

  Future<void> _maintain() async {
    if (!await isCurrent()) return;
    final result = await _maintenance.run(_config.id);
    if (result case Err(:final failure)) {
      log.warning('Ark foreground maintenance failed: ${failure.runtimeType}');
    }
    // An interrupted Board must not hold the wallet's coins until the next
    // Board attempt: settle it here too.
    await _reconcileBoard();
  }

  /// Records a confirmed Board, or releases one that can never be signed,
  /// so its coins stop being held.
  Future<void> _reconcileBoard() async {
    if (_board case final WalletArkBoardFunding funding) {
      final board = await funding.reconcilePending(_config.id);
      if (board case Err(:final failure)) {
        log.warning('Ark board reconcile failed: ${failure.runtimeType}');
      }
    }
  }

  /// Synchronously prevents further native stages and invalidates the UI.
  void invalidate() {
    _policy.active = false;
    feature.invalidate();
  }

  /// Wait for admitted native work; the custody registry remains app-owned.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    Object? error;
    StackTrace? trace;
    _exitPolling?.cancel();
    try {
      invalidate();
    } catch (failure, stack) {
      error = failure;
      trace = stack;
    }
    try {
      await _maintenance.close();
    } catch (failure, stack) {
      error ??= failure;
      trace ??= stack;
    }
    try {
      await _closeBoardFunding();
    } catch (failure, stack) {
      error ??= failure;
      trace ??= stack;
    }
    try {
      final handle = _clientHandle;
      if (handle == null) {
        await _client.close();
      } else {
        await handle.close();
      }
    } catch (failure, stack) {
      error ??= failure;
      trace ??= stack;
    }
    try {
      await _exitNotifier?.close();
    } catch (failure, stack) {
      error ??= failure;
      trace ??= stack;
    }
    if (error != null && trace != null) Error.throwWithStackTrace(error, trace);
    if (error != null) throw error;
  }
}

/// Install Ark custody references before either seed-deletion path is exposed.
///
/// An absent or incompatible existing registry leaves a registered owner that
/// refuses inventory. [initializeNew] is only for an independently authorized
/// first regtest setup; it must never be inferred from absent local files.
Future<Result<void, ArkFailure>> prepareArkCustodyReferences(
  GetIt locator, {
  required bool initializeNew,
}) async {
  try {
    return await _referenceOwnerFor(locator).ensureOpen(initializeNew);
  } on Exception {
    return const Err(ArkFeatureStorageFailure());
  }
}

/// Open the foreground composition after wallet services are registered.
///
/// [initializeNew] is an explicit host authorization for a controlled first
/// regtest setup, before any Ark funding can occur. Missing files or disabled
/// preferences alone are not evidence of first setup. Ordinary restarts must
/// pass false. The endpoints are supplied by the explicitly configured regtest
/// profile; a loopback host is valid there, for example over an ADB bridge.
Future<Result<ArkForegroundRuntime, ArkFailure>> openArkForeground(
  GetIt locator, {
  required Uri arkUrl,
  required Uri primaryEsploraUrl,
  required bool initializeNew,
  required ArkBoardFundingBinding boardFunding,
  required WalletInventory inventory,
  ArkPreferencesRepository? preferences,
  BackgroundTaskDispatcher? dispatcher,
  ArkScanner? scanner,
  ArkAppServices services = const ArkAppServices(),
}) async {
  try {
    final selection = _WalletArkSelection(
      locator<ActiveEnvironmentReader>(),
      inventory,
      arkUrl,
      primaryEsploraUrl,
    );
    final selected = await selection.selectedAccount();
    final config = switch (selected) {
      Ok(:final value) => value,
      Err(:final failure) => throw _SelectionFailure(failure),
    };

    // The host also invokes this during startup before deletion is exposed.
    final prepared = await prepareArkCustodyReferences(
      locator,
      initializeNew: initializeNew,
    );
    if (prepared case Err(:final failure)) return Err(failure);
    final referenceOwner = _referenceOwnerFor(locator);
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/ark');
    final registry = referenceOwner.registry;
    if (registry == null) return const Err(ArkFeatureStorageFailure());

    final locale = await () async {
      try {
        final language =
            (await locator<RuntimeDisplayPreferencesReader>().readLanguage())
                .fold(
                  (value) => value,
                  (failure) => throw Exception('Preferences read failed'),
                );
        return language == null
            ? const Locale('en')
            : Locale.fromSubtags(
                languageCode: language.languageCode,
                scriptCode: language.scriptCode,
                countryCode: language.countryCode,
              );
      } catch (failure, stack) {
        try {
          await boardFunding.close();
        } catch (_) {}
        Error.throwWithStackTrace(failure, stack);
      }
    }();
    OwnedArkExitNotifier? exitNotifier;
    if (Platform.isAndroid && locator.isRegistered<RuntimeAdmission>()) {
      try {
        exitNotifier = await openForegroundArkExitNotifier(
          documents: documents.path,
          directory: directory.path,
          locale: locale,
          admission: locator<RuntimeAdmission>(),
        );
      } on Exception {
        log.warning('Ark payment notification store unavailable');
      } catch (failure, stack) {
        try {
          await boardFunding.close();
        } catch (_) {}
        Error.throwWithStackTrace(failure, stack);
      }
    }
    final policy = _ForegroundPolicy(config.id);
    late final Secrets secrets;
    ArkClient? createdClient;
    late final ArkClient client;
    LifecycleHandle? clientHandle;
    try {
      secrets = locator<Secrets>();
      client = createArkNativeClient(
        storagePath: '${directory.path}/native',
        childProvider: SecretsArkChildProvider(secrets, registry),
        transactionVerifier: const ArkTransactionVerifier(),
        boardAbandonment: WalletArkBoardAbandonment(
          locator.isRegistered<SqliteArkFundingReservations>()
              ? Ok(locator<SqliteArkFundingReservations>())
              : const Err(SyncStorageFailure()),
        ),
        executionPolicy: policy,
        executionMode: native.ArkExecutionMode.foreground,
        stageBudget: const native.ArkUnlimitedStageBudget(),
        exitObserver: exitNotifier?.combined,
      );
      createdClient = client;
      if (locator.isRegistered<RuntimeAdmission>()) {
        clientHandle = locator<RuntimeAdmission>().track(client.close);
      }
    } catch (failure, stack) {
      try {
        await createdClient?.close();
      } catch (_) {}
      try {
        await exitNotifier?.close();
      } catch (_) {}
      try {
        await boardFunding.close();
      } catch (_) {}
      Error.throwWithStackTrace(failure, stack);
    }
    ArkForegroundMaintenance? maintenance;
    WalletArkDisplayData? displayData;
    final exitFunding = ArkExitFunding();
    // Scuttle funds the exit reserve only through a journaled, reviewed
    // transfer; the unjournaled automatic top-up is not wired.
    const ArkReserveTopUpPort? exitTopUp = null;
    try {
      final openedMaintenance = await openArkForegroundMaintenance(
        path: '${directory.path}/reminders.sqlite',
        locale: locale,
        client: client,
        accounts: registry,
        initializeNew: initializeNew,
        permitsParent: inventory.mayNotifyArk,
        // An exit's fees come from Secure Bitcoin when it needs them. Built
        // on first use: opening Ark never needs the send stack.
        exitTopUp: exitTopUp,
        exitFunding: exitFunding,
      );
      if (openedMaintenance case Err(:final failure)) {
        throw _SelectionFailure(failure);
      }
      maintenance =
          (openedMaintenance as Ok<ArkForegroundMaintenance, ArkFailure>).value;
      if (!maintenance.remindersReady) {
        log.warning('Ark expiry reminders unavailable');
      }
      final managedRegistry = dispatcher == null
          ? registry
          : _ScheduledArkRegistry(registry, dispatcher);
      final board = boardFunding.bind(client, selection.sourceWalletId);
      if (locator.isRegistered<WalletNativeRuntime>()) {
        final settings = locator<RuntimeDisplayPreferencesReader>();
        displayData = WalletArkDisplayData(
          runtime: locator<WalletNativeRuntime>(),
          account: config.id,
          selectedSource: selection.displaySourceWalletId,
          currency: () async => (await settings.readCurrency()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          ),
          currencyChanges: settings.currencyChangeStream.expand<String>(
            (result) => result.fold((value) => [value], (_) => const []),
          ),
          walletName: services.walletName ?? (_) async => null,
          isActive: () => policy.active,
        );
      }
      final feature = ArkFeature(
        selection,
        config: config,
        client: client,
        preferences: preferences ?? SharedPreferencesArkPreferencesRepository(),
        paymentAnimations: locator.isRegistered<Preferences>()
            ? locator<Preferences>()
            : null,
        provisioning: ArkCustodyProvisioner(
          locator<ParentCustodyAdmissionPort>(),
          SecretsArkParentPresence(secrets),
          managedRegistry,
          ArkDerivationCollision(locator<Bip85Derivations>()),
        ),
        registry: managedRegistry,
        boardFunding: board,
        displayData: displayData,
        exitFunding: exitFunding,
        savedExitDestination: switch (board) {
          WalletArkBoardFunding actor => (
            ids,
          ) => actor.readInitialExitDestination(config.id, ids),
          _ => null,
        },
        fundInitialExit: switch (board) {
          WalletArkBoardFunding actor => (quote, address) async {
            if (!policy.active || quote.account != config.id) {
              return const Err(ArkServiceUnavailableFailure());
            }
            return actor.fundInitialExit(
              quote,
              address,
              isCurrent: () => policy.active,
            );
          },
          _ => null,
        },
        exitDestination: switch (services.nextReceiveAddress) {
          final nextAddress? => WalletArkExitDestination(
            sourceWallet: selection.displaySourceWalletId,
            nextAddress: nextAddress,
          ),
          null => null,
        },
        scanner: scanner,
        walletBackground: services.walletBackground,
        confirmIcon: services.confirmIcon,
        onHome: services.onHome,
      );
      final runtime = ArkForegroundRuntime._(
        feature,
        client,
        clientHandle,
        () async {
          await _closeArkDisplayAndBoard(displayData, boardFunding.close);
          await exitFunding.close();
        },
        policy,
        maintenance,
        selection,
        config,
        board,
        exitNotifier,
      );
      final registered = await registry.list();
      if (registered case Ok(:final value)
          when value.any((item) => item.id == config.id)) {
        unawaited(runtime.maintain());
        runtime._pollExits();
      }
      return Ok(runtime);
    } catch (failure, stack) {
      // The binding may hold this client, so its admitted work must drain
      // before the client, even if construction fails. Preserve the failure.
      policy.active = false;
      try {
        await maintenance?.close();
      } catch (_) {}
      try {
        await _closeArkDisplayAndBoard(displayData, boardFunding.close);
      } catch (_) {}
      try {
        if (clientHandle == null) {
          await client.close();
        } else {
          await clientHandle.close();
        }
      } catch (_) {}
      try {
        await exitNotifier?.close();
      } catch (_) {}
      Error.throwWithStackTrace(failure, stack);
    }
  } on _SelectionFailure catch (failure) {
    return Err(failure.failure);
  } on Exception {
    return const Err(ArkFeatureStorageFailure());
  }
}

/// Reschedule from durable custody inventory; failed reads never cancel work.
Future<bool> prepareArkMaintenanceSchedule(
  GetIt locator,
  BackgroundTaskDispatcher dispatcher, {
  BackgroundTaskSchedulerPort? scheduler,
}) async {
  final registry = _referenceOwnerFor(locator).registry;
  if (registry == null) return false;
  final scheduled = await scheduleArkMaintenance(
    accounts: registry,
    dispatcher: dispatcher,
    scheduler: scheduler,
  );
  if (scheduled case Err(:final failure)) {
    log.warning('Ark maintenance scheduling failed: ${failure.runtimeType}');
  }
  return switch (await registry.list()) {
    Ok(:final value) => value.isNotEmpty,
    Err() => false,
  };
}

Future<void> _closeArkDisplayAndBoard(
  WalletArkDisplayData? display,
  Future<void> Function() closeBoard,
) async {
  try {
    await display?.close();
  } finally {
    await closeBoard();
  }
}

/// Publication is durable before scheduling; failure never erases the account.
final class _ScheduledArkRegistry implements ArkAccountRegistryRepository {
  final ArkAccountRegistryRepository _delegate;
  final BackgroundTaskDispatcher _dispatcher;
  final BackgroundTaskSchedulerPort? scheduler;
  const _ScheduledArkRegistry(
    this._delegate,
    this._dispatcher, {
    this.scheduler,
  });

  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() => _delegate.list();

  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async {
    final result = await _delegate.publish(config);
    if (result is Ok) {
      final scheduled = await scheduleArkMaintenance(
        accounts: _delegate,
        dispatcher: _dispatcher,
        scheduler: scheduler,
      );
      if (scheduled case Err(:final failure)) {
        log.warning(
          'Ark maintenance scheduling failed: ${failure.runtimeType}',
        );
      }
    }
    return result;
  }
}

@visibleForTesting
ArkAccountRegistryRepository scheduledArkRegistryForTesting(
  ArkAccountRegistryRepository registry,
  BackgroundTaskDispatcher dispatcher,
  BackgroundTaskSchedulerPort scheduler,
) => _ScheduledArkRegistry(registry, dispatcher, scheduler: scheduler);

final class _SelectionFailure implements Exception {
  final ArkFailure failure;
  const _SelectionFailure(this.failure);
}

final class _WalletArkSelection implements ArkAccountSelectionPort {
  final ActiveEnvironmentReader _settings;
  final WalletInventory _wallets;
  final Uri _arkUrl;
  final Uri _esploraUrl;

  const _WalletArkSelection(
    this._settings,
    this._wallets,
    this._arkUrl,
    this._esploraUrl,
  );

  @override
  Future<Result<ArkAccountConfig, ArkFailure>> selectedAccount() async {
    switch (await _select()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(value.$1);
    }
  }

  /// Resolve the current wallet again; the caller cannot select a wallet ID.
  Future<String> sourceWalletId(ArkAccountId account) async {
    switch (await _select()) {
      case Ok(:final value) when value.$1.id == account:
        return value.$2;
      case Ok():
      case Err():
        throw StateError('Ark source wallet is unavailable or changed');
    }
  }

  Future<Result<String, ArkFailure>> displaySourceWalletId(
    ArkAccountId account,
  ) async => switch (await _select()) {
    Ok(:final value) when value.$1.id == account => Ok(value.$2),
    Err(:final failure) => Err(failure),
    _ => const Err(ArkAccountRecoveryFailure()),
  };

  Future<Result<(ArkAccountConfig, String), ArkFailure>> _select() async {
    try {
      if ((await _settings.readActiveEnvironment()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          ) !=
          Environment.regtest) {
        return const Err(ArkNetworkUnavailableFailure());
      }
      final selected = await _wallets.walletsForNetwork(BitcoinNetwork.regtest);
      if (selected case Err()) return const Err(ArkFeatureStorageFailure());
      final wallets = (selected as Ok<WalletSelection, SecretFailure>).value;
      if (!wallets.isComplete) return const Err(ArkFeatureStorageFailure());
      final eligible = wallets.defaults
          .where(
            (wallet) =>
                wallet.signer == WalletSigner.local &&
                wallet.secretFingerprint != null,
          )
          .toList();
      if (eligible.length != 1) return const Err(ArkAccountRecoveryFailure());
      final parent = eligible.single.secretFingerprint;
      if (parent == null) return const Err(ArkAccountRecoveryFailure());
      return Ok((
        ArkAccountConfig(
          id: ArkAccountId(
            parent: parent,
            network: BitcoinNetwork.regtest,
            serverIdentity: _arkUrl.toString(),
          ),
          arkUrl: _arkUrl,
          primaryEsploraUrl: _esploraUrl,
        ),
        eligible.single.id,
      ));
    } on Exception {
      return const Err(ArkFeatureStorageFailure());
    }
  }
}

final class _ForegroundPolicy implements native.ArkExecutionPolicyPort {
  final ArkAccountId _account;
  bool active = true;
  _ForegroundPolicy(this._account);

  @override
  bool mayRun(ArkAccountId account, native.ArkExecutionMode mode) =>
      active &&
      account == _account &&
      account.network == BitcoinNetwork.regtest &&
      mode == native.ArkExecutionMode.foreground;
}

_RegistryReferenceOwner _referenceOwnerFor(GetIt locator) {
  if (locator.isRegistered<_RegistryReferenceOwner>()) {
    return locator<_RegistryReferenceOwner>();
  }
  final owner = _RegistryReferenceOwner(
    locator.isRegistered<ArkInstallationState>()
        ? locator<ArkInstallationState>()
        : null,
  );
  locator<SeedReferences>().register(owner);
  locator.registerSingleton<_RegistryReferenceOwner>(
    owner,
    dispose: (value) => value.close(),
  );
  return owner;
}

/// Registered once per app isolate, and refuses inventory while unavailable.
final class _RegistryReferenceOwner implements SeedReferencePort {
  final ArkInstallationState? _installation;
  SqliteArkAccountRegistry? _registry;
  Future<Result<void, ArkFailure>>? _opening;
  bool _closing = false;

  _RegistryReferenceOwner(this._installation);

  SqliteArkAccountRegistry? get registry => _registry;

  Future<Result<void, ArkFailure>> ensureOpen(bool initializeNew) {
    if (_closing) return Future.value(const Err(ArkFeatureStorageFailure()));
    if (_registry != null) return Future.value(const Ok(null));
    // Every retry, including profile/runtime setup, retains startup's refusal
    // to initialize over surviving custody state.
    final mayInitialize =
        initializeNew && (_installation?.wasNeverProvisioned ?? true);
    return _opening ??= _open(mayInitialize)
        .whenComplete(() => _opening = null);
  }

  Future<Result<void, ArkFailure>> _open(bool initializeNew) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/ark');
      if (!initializeNew &&
          await _installation?.remainsUnprovisioned() == true) {
        return const Ok(null);
      }
      if (initializeNew) await directory.create(recursive: true);
      final path = '${directory.path}/accounts.sqlite';
      final hasDatabase = File(path).existsSync();
      final hasMarker = File('$path.initialized').existsSync();
      // Explicit first-setup authority does not authorize adopting a surviving
      // orphan or recreating a lost database whose marker still exists.
      if (initializeNew && hasDatabase != hasMarker) {
        return const Err(ArkFeatureStorageFailure());
      }
      switch (SqliteArkAccountRegistry.open(
        path,
        foreground: true,
        initializeNew: initializeNew && !hasDatabase && !hasMarker,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          _registry = value;
          return const Ok(null);
      }
    } on Exception {
      return const Err(ArkFeatureStorageFailure());
    }
  }

  Future<void> close() async {
    _closing = true;
    final opening = _opening;
    if (opening != null) await opening;
    final registry = _registry;
    _registry = null;
    registry?.close();
  }

  @override
  Future<Result<Set<Fingerprint>, Failure>> getCustodyFingerprints() async {
    final registry = _registry;
    if (registry == null) {
      return await _installation?.remainsUnprovisioned() == true
          ? const Ok({})
          : const Err(SeedReferencesUnavailable());
    }
    return registry.getCustodyFingerprints();
  }
}
