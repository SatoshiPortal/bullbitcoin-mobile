import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/data/ark_transaction_verifier.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

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
  final Future<void> Function() _closeBoardFunding;
  final _ForegroundPolicy _policy;
  final _WalletArkSelection _selection;
  final ArkAccountConfig _config;
  Future<void>? _closing;

  ArkForegroundRuntime._(
    this.feature,
    this._client,
    this._closeBoardFunding,
    this._policy,
    this._selection,
    this._config,
  );

  /// The selected account this runtime was opened for.
  ArkAccountId get account => _config.id;

  /// Whether this runtime is open and still matches the current wallet
  /// selection. A stale runtime must be invalidated and closed by its owner.
  Future<bool> isCurrent() async {
    if (!_policy.active) return false;
    return switch (await _selection.selectedAccount()) {
          Ok(:final value) =>
            value.id == _config.id &&
                value.arkUrl == _config.arkUrl &&
                value.primaryEsploraUrl == _config.primaryEsploraUrl,
          Err() => false,
        } &&
        _policy.active;
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
    try {
      invalidate();
    } catch (failure, stack) {
      error = failure;
      trace = stack;
    }
    try {
      await _closeBoardFunding();
    } catch (failure, stack) {
      error ??= failure;
      trace ??= stack;
    }
    try {
      await _client.close();
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
  ArkPreferencesRepository? preferences,
}) async {
  try {
    final selection = _WalletArkSelection(
      locator<SettingsRepository>(),
      locator<WalletMetadataDatasource>(),
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

    final secrets = locator<Secrets>();
    final policy = _ForegroundPolicy(config.id);
    final client = createArkNativeClient(
      storagePath: '${directory.path}/native',
      childProvider: SecretsArkChildProvider(secrets, registry),
      transactionVerifier: const ArkTransactionVerifier(),
      executionPolicy: policy,
      executionMode: native.ArkExecutionMode.foreground,
      stageBudget: const native.ArkUnlimitedStageBudget(),
    );
    try {
      final board = boardFunding.bind(client, selection.sourceWalletId);
      final feature = ArkFeature(
        selection,
        config: config,
        client: client,
        preferences: preferences ?? SharedPreferencesArkPreferencesRepository(),
        provisioning: ArkCustodyProvisioner(
          locator<ParentCustodyAdmissionPort>(),
          SecretsArkParentPresence(secrets),
          registry,
          ArkDerivationCollision(locator<Bip85Repository>()),
        ),
        registry: registry,
        boardFunding: board,
      );
      return Ok(
        ArkForegroundRuntime._(
          feature,
          client,
          boardFunding.close,
          policy,
          selection,
          config,
        ),
      );
    } catch (failure, stack) {
      // The binding may hold this client, so its admitted work must drain
      // before the client, even if construction fails. Preserve the failure.
      policy.active = false;
      try {
        await boardFunding.close();
      } catch (_) {}
      try {
        await client.close();
      } catch (_) {}
      Error.throwWithStackTrace(failure, stack);
    }
  } on _SelectionFailure catch (failure) {
    return Err(failure.failure);
  } on Exception {
    return const Err(ArkFeatureStorageFailure());
  }
}

final class _SelectionFailure implements Exception {
  final ArkFailure failure;
  const _SelectionFailure(this.failure);
}

final class _WalletArkSelection implements ArkAccountSelectionPort {
  final SettingsRepository _settings;
  final WalletMetadataDatasource _wallets;
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

  Future<Result<(ArkAccountConfig, String), ArkFailure>> _select() async {
    try {
      if ((await _settings.fetch()).environment != Environment.regtest) {
        return const Err(ArkNetworkUnavailableFailure());
      }
      final eligible = (await _wallets.fetchAll())
          .where(
            (wallet) =>
                wallet.networkCode == 'bitcoinRegtest' &&
                wallet.signer == Signer.local &&
                wallet.isDefault &&
                wallet.seedFingerprint != null,
          )
          .toList();
      if (eligible.length != 1) return const Err(ArkAccountRecoveryFailure());
      final parent = eligible.single.seedFingerprint;
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

/// Reads every historical BIP85 record, including revoked derivations.
final class ArkDerivationCollision implements ArkChildCollisionPort {
  final Bip85Repository _registry;
  const ArkDerivationCollision(this._registry);

  @override
  Future<Result<bool, ArkFailure>> hasCollision(Fingerprint parent) async {
    switch (await _registry.fetchAll()) {
      case Err():
        return const Err(ArkFeatureStorageFailure());
      case Ok(:final value):
        for (final record in value) {
          final owner = Fingerprint.tryParse(
            record.xprvFingerprint.toLowerCase(),
          );
          if (owner == null) return const Err(ArkFeatureStorageFailure());
          if (owner == parent && record.application == Bip85Application.bip39) {
            // The existing datasource stores the four hardened application
            // components without the common BIP85 root prefix. An unknown
            // representation cannot certify that this child is unused.
            if (record.path.length > 128) {
              return const Err(ArkFeatureStorageFailure());
            }
            final path = RegExp(r"^39'/([0-9]+)'/([0-9]+)'/([0-9]+)'$")
                .firstMatch(record.path);
            if (path == null) return const Err(ArkFeatureStorageFailure());
            final language = int.tryParse(path.group(1) ?? '');
            final words = int.tryParse(path.group(2) ?? '');
            final index = int.tryParse(path.group(3) ?? '');
            if (language == null ||
                words == null ||
                index == null ||
                language > 0x7fffffff ||
                index > 0x7fffffff ||
                !const {12, 15, 18, 21, 24}.contains(words)) {
              return const Err(ArkFeatureStorageFailure());
            }
            if (language == 0 && words == 12 && index == 11811) {
              return const Ok(true);
            }
          }
        }
        return const Ok(false);
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
  final owner = _RegistryReferenceOwner();
  locator<SeedReferences>().register(owner);
  locator.registerSingleton<_RegistryReferenceOwner>(
    owner,
    dispose: (value) => value.close(),
  );
  return owner;
}

/// Registered once per app isolate, and refuses inventory while unavailable.
final class _RegistryReferenceOwner implements SeedReferencePort {
  SqliteArkAccountRegistry? _registry;
  Future<Result<void, ArkFailure>>? _opening;
  bool _closing = false;

  SqliteArkAccountRegistry? get registry => _registry;

  Future<Result<void, ArkFailure>> ensureOpen(bool initializeNew) {
    if (_closing) return Future.value(const Err(ArkFeatureStorageFailure()));
    if (_registry != null) return Future.value(const Ok(null));
    return _opening ??= _open(initializeNew)
        .whenComplete(() => _opening = null);
  }

  Future<Result<void, ArkFailure>> _open(bool initializeNew) async {
    try {
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory('${documents.path}/ark');
      await directory.create(recursive: true);
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
    if (registry == null) return const Err(SeedReferencesUnavailable());
    return registry.getCustodyFingerprints();
  }
}
