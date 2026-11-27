import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart' show Preferences;
import 'package:primitives/primitives.dart';

import '../log.dart';
import '../swap_engine_switcher.dart';
import 'entities/regtest_boltz_profile.dart';
import 'entities/swap_failure.dart';
import 'entities/swap_server.dart';
import 'swap_server_setting_repository.dart';
import 'swap_store.dart';

/// Provider settings for the current environment.
abstract interface class SwapServerSettings {
  @useResult
  Future<Result<({SwapServer server, NetworkEnv environment}), SwapsFailure>>
  readServer();

  @useResult
  Future<Result<SwapServer, SwapsFailure>> setServer(
    String input, {
    SwapServerCredentials? credentials,
  });
}

final class SwapServerControl implements SwapServerSettings {
  final Preferences _preferences;
  final SwapServerSettingRepository _servers;
  final SwapEngineSwitcher _switcher;
  final SwapStore _store;

  const SwapServerControl({
    required Preferences settingsRepository,
    required SwapServerSettingRepository swapServerSettingRepository,
    required SwapEngineSwitcher swapEngineSwitcher,
    required SwapStore swapStore,
  }) : _preferences = settingsRepository,
       _servers = swapServerSettingRepository,
       _switcher = swapEngineSwitcher,
       _store = swapStore;

  @override
  @useResult
  Future<Result<({SwapServer server, NetworkEnv environment}), SwapsFailure>>
  readServer() async {
    try {
      final environment = await readSwapEnvironment(_preferences);
      if (environment == NetworkEnv.regtest &&
          !RegtestHostProfile.isConfigured) {
        return const Err(SwapsUnsupportedNetworkFailure());
      }
      final profile = RegtestBoltzProfile.forNetwork(environment);
      if (profile != null) {
        final server = SwapServer.parse(
          profile.api.toString(),
          isTestnet: true,
        );
        if (server == null) {
          return const Err(
            SwapsInvalidServerFailure('invalid regtest endpoint'),
          );
        }
        return Ok((server: server, environment: environment));
      }
      if (environment == NetworkEnv.signet) {
        return const Err(SwapsUnsupportedNetworkFailure());
      }
      final server = await _servers.fetch(
        isTestnet: environment == NetworkEnv.testnet,
      );
      return Ok((server: server, environment: environment));
    } on SwapsFailure catch (failure) {
      return Err(failure);
    } on Exception catch (error) {
      return Err(SwapsStorageFailure(error.runtimeType.toString()));
    }
  }

  @override
  @useResult
  Future<Result<SwapServer, SwapsFailure>> setServer(
    String input, {
    SwapServerCredentials? credentials,
  }) async {
    try {
      final environment = await readSwapEnvironment(_preferences);
      if (environment != NetworkEnv.mainnet &&
          environment != NetworkEnv.testnet) {
        return const Err(SwapsUnsupportedNetworkFailure());
      }
      final isTestnet = environment == NetworkEnv.testnet;
      final parsed = SwapServer.parse(input, isTestnet: isTestnet);
      if (parsed == null) {
        return const Err(SwapsInvalidServerFailure('not an address'));
      }
      if (credentials != null && !credentials.isValid) {
        return const Err(SwapsInvalidServerFailure('colon in username'));
      }
      final server = parsed.withCredentials(credentials);
      if (server.isPlaintext && !isTestnet) {
        return const Err(
          SwapsInvalidServerFailure('plaintext outside testnet'),
        );
      }
      // New credentials for the same server leave open swaps where they
      // are, and are what lets them reach it again.
      final stored = await _servers.fetch(isTestnet: isTestnet);
      if (server.host != stored.host) {
        final now = DateTime.now();
        switch (await _store.ongoing()) {
          case Ok(value: final open)
              when open.any((swap) => swap.mayStillNeedProvider(now)):
            return const Err(SwapsBusyFailure());
          case Err():
            return const Err(SwapsStorageFailure());
          case Ok():
        }
      }
      await _servers.save(server, isTestnet: isTestnet);
      return (await _switcher.rebuild(
        environment: environment,
        waitForCompletion: true,
      )).map((_) => server);
    } on SwapsFailure catch (failure) {
      return Err(failure);
    } on Exception catch (error) {
      swapsLog.warning('Swap server not saved (${error.runtimeType})');
      return Err(SwapsStorageFailure(error.runtimeType.toString()));
    }
  }
}

Future<NetworkEnv> readSwapEnvironment(Preferences preferences) async =>
    switch (await preferences.fetch()) {
      Ok(:final value) => value.environment.networkEnv,
      Err() => throw const SwapsStorageFailure('Preferences read failed'),
    };
