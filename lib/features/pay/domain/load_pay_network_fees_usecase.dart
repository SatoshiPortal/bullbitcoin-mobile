import 'package:fees/fees.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    as wallet
    show Network, NetworkX;
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadPayNetworkFeesUsecase {
  final Fees _fees;
  final Preferences _preferences;

  const LoadPayNetworkFeesUsecase({
    required this._fees,
    required this._preferences,
  });

  @useResult
  Future<Result<FeeOptions, PayFailure>> execute({
    required bool isLiquid,
  }) async {
    try {
      final SettingsEntity settings;
      switch (await _preferences.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err(:final failure):
          final reason = 'Preferences read failed: ${failure.runtimeType}';
          log.warning(reason);
          return Err(PayFeesUnavailableFailure(reason));
      }
      final network = wallet.Network.fromEnvironment(
        environment: settings.environment.networkEnv,
        isLiquid: isLiquid,
      );
      switch (await _fees.estimate(network.shared)) {
        case Ok(:final value):
          return Ok(value);
        case Err(:final failure):
          final reason =
              'Network fee estimation unavailable: ${failure.runtimeType}';
          log.warning(reason);
          return Err(PayFeesUnavailableFailure(reason));
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load the network fees',
        error: e,
        trace: st,
      );
      // Actionable: the fee cannot be picked, and retrying is the whole cure.
      return Err(PayFeesUnavailableFailure('$e'));
    }
  }
}
