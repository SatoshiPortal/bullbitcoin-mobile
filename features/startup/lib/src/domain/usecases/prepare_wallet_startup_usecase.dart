import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart' show SwapStartup;

import '../app_startup_failure.dart';
import 'check_for_existing_default_wallets_usecase.dart';
import 'get_startup_pin_status_usecase.dart';
import 'initialize_required_tor_usecase.dart';

class PrepareWalletStartupUsecase {
  final GetStartupPinStatusUsecase _checkPin;
  final CheckForExistingDefaultWalletsUsecase _checkWallets;
  final SwapStartup _swaps;
  final InitializeRequiredTorUsecase _tor;

  const PrepareWalletStartupUsecase(
    this._checkPin,
    this._checkWallets,
    this._swaps,
    this._tor,
  );

  @useResult
  Future<
    Result<({bool requiresPin, bool hasDefaultWallets}), AppStartupFailure>
  >
  execute({required bool authenticated}) async {
    if (!authenticated) {
      switch (await _checkPin.execute()) {
        case Ok(value: true):
          return const Ok((requiresPin: true, hasDefaultWallets: false));
        case Ok(value: false):
          break;
        case Err(:final failure):
          return Err(failure);
      }
    }

    switch (await _checkWallets.execute()) {
      case Ok(:final value):
        if (value) await _swaps.execute();
        unawaited(_warmTor());
        return Ok((requiresPin: false, hasDefaultWallets: value));
      case Err(:final failure):
        return Err(failure);
    }
  }

  Future<void> _warmTor() async {
    try {
      await _tor.execute();
    } catch (error, stackTrace) {
      log.severe(
        message: 'Required Tor initialization failed',
        error: error,
        trace: stackTrace,
      );
    }
  }
}
