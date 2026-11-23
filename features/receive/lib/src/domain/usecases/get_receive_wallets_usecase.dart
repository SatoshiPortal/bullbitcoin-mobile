import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:receive/src/domain/receive_wallet.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' as native;
import 'package:signers/storage.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:preferences/preferences.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';

typedef LoadReceiveWallet =
    Future<Result<native.Wallet, native.SyncFailure>> Function(
      native.WalletKey key,
    );

class GetReceiveWalletsUsecase {
  final ActiveEnvironmentReader _environment;
  final WalletInventory _inventory;
  final LoadReceiveWallet _loadWallet;
  final SignerDevices _devices;

  const GetReceiveWalletsUsecase(
    this._environment,
    this._inventory,
    this._loadWallet,
    this._devices,
  );

  @useResult
  Future<Result<List<ReceiveWallet>, ReceiveFailure>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
  }) async {
    final environment = await _environment.readActiveEnvironment();
    if (environment case Err(:final failure)) return _loadFailed(failure);
    final env =
        (environment as Ok<Environment, PreferencesFailure>).value.networkEnv;
    final networks = [
      if (onlyLiquid != true)
        ...BitcoinNetwork.values.where((n) => n.env == env),
      if (onlyBitcoin != true)
        ...LiquidNetwork.values.where((n) => n.env == env),
    ];
    final registrations = <WalletRegistration>[];
    for (final network in networks) {
      switch (await _inventory.walletsForNetwork(network)) {
        case Err(:final failure):
          return _loadFailed(failure);
        case Ok(:final value):
          registrations.addAll(
            value.wallets.where(
              (wallet) => onlyDefaults != true || wallet.isDefault,
            ),
          );
      }
    }
    if (registrations.isEmpty) {
      return const Err(ReceiveAddressUnavailableFailure());
    }
    final wallets = await Future.wait(registrations.map(_project));
    return Ok(wallets.whereType<ReceiveWallet>().toList());
  }

  @useResult
  Future<Result<ReceiveWallet, ReceiveFailure>> resolveEntry(
    ReceiveWallet entry,
  ) async {
    final environment = await _environment.readActiveEnvironment();
    if (environment case Err(:final failure)) return _loadFailed(failure);
    final env =
        (environment as Ok<Environment, PreferencesFailure>).value.networkEnv;
    if (entry.network.env != env) {
      return const Err(ReceiveUnsupportedNetworkFailure());
    }
    switch (await _inventory.readWallet(entry.id)) {
      case Err(:final failure):
        return _loadFailed(failure);
      case Ok(:final value):
        if (value.network != entry.network) {
          return const Err(ReceiveUnsupportedNetworkFailure());
        }
        final wallet = await _project(value);
        return wallet == null
            ? const Err(ReceiveAddressUnavailableFailure())
            : Ok(wallet);
    }
  }

  Future<ReceiveWallet?> _project(WalletRegistration registration) async {
    final device = await _devices.read(registration.id);
    if (device case Err(:final failure)) {
      log.warning(
        'Failed to read receive wallet signer: ${failure.runtimeType}',
      );
      return null;
    }
    final loaded = await _loadWallet(
      native.WalletKey(id: registration.id, network: registration.network),
    );
    final balance = switch (loaded) {
      Ok(:final value) => value.balances.now.data?.totalSat,
      Err(:final failure) => _unavailableBalance(failure),
    };
    return ReceiveWallet(
      id: registration.id,
      network: registration.network,
      signsLocally: registration.signer == WalletSigner.local,
      isDefault: registration.isDefault,
      label: registration.label,
      scriptType: registration.scriptType,
      derivationPath: registration.derivationPath,
      signerDevice: (device as Ok<SignerDevice?, SignerDeviceFailure>).value,
      balanceSat: balance,
    );
  }

  static BigInt? _unavailableBalance(native.SyncFailure failure) {
    log.warning(
      'Failed to read receive wallet balance: ${failure.runtimeType}',
    );
    return null;
  }

  /// Selection is receive policy; the bloc only projects its outcome.
  @useResult
  static Result<
    ({ReceiveWallet wallet, List<ReceiveWallet> choices}),
    ReceiveFailure
  >
  selectBitcoin({
    required Result<List<ReceiveWallet>, ReceiveFailure> catalog,
    ReceiveWallet? explicitWallet,
    ReceiveWallet? entryWallet,
    ReceiveWallet? currentWallet,
  }) {
    final selected =
        explicitWallet ??
        (entryWallet?.isBitcoin == true ? entryWallet : null) ??
        currentWallet;
    return switch (catalog) {
      Err(:final failure) =>
        selected == null
            ? Err(failure)
            : Ok((wallet: selected, choices: [selected])),
      Ok(:final value) =>
        selected != null
            ? Ok((wallet: selected, choices: value))
            : value.isEmpty
            ? const Err(ReceiveAddressUnavailableFailure())
            : Ok((
                wallet: value.firstWhere(
                  (wallet) => wallet.isDefault,
                  orElse: () => value.first,
                ),
                choices: value,
              )),
    };
  }

  Err<T, ReceiveFailure> _loadFailed<T>(Failure failure) {
    log.warning('Failed to load wallets for receive: ${failure.runtimeType}');
    return Err(ReceiveAddressUnavailableFailure());
  }
}
