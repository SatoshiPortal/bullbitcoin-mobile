/// Wallet-owned composition of Board funding; never a shell data adapter.
library;

import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart'
    show ArkBoardFundingPort, ArkFailure, ArkServiceUnavailableFailure;
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'package:fees/fees.dart';

import '../data/ark_board_funding.dart';
import '../data/foreground_wallet_sync.dart';
import '../data/wallet_registrations.dart';

import 'package:sync/write.dart' show WalletNativeRuntime;

/// Construct before ArkClient, bind once after the SAME real client exists.
final class WalletArkFundingFactory {
  final SqliteArkFundingReservations _authority;
  final WalletNativeRuntime _runtime;
  final WalletRegistrations _metadata;
  final ForegroundWalletSync _sourceSync;
  final Secrets _secrets;
  final Fees _fees;
  final ParentCustodyAdmissionPort _custody;
  WalletArkBoardFunding? _actor;
  bool _closed = false;

  WalletArkFundingFactory({
    required this._authority,
    required this._runtime,
    required this._metadata,
    required this._sourceSync,
    required this._secrets,
    required this._fees,
    required this._custody,
  });

  ArkBoardFundingPort bindRealClient(
    ArkClient client,
    Future<String> Function(ArkAccountId account) sourceWalletId,
  ) {
    if (!_runtime.usesFundingReservations(_authority)) {
      throw StateError(
        'Wallet Ark funding authority is not configured in Sync',
      );
    }
    if (_closed || _actor != null) {
      throw StateError('Wallet Ark funding factory already bound or closed');
    }
    final actor = WalletArkBoardFunding(
      authority: _authority,
      runtime: _runtime,
      metadata: _metadata,
      sourceSync: _sourceSync,
      secrets: _secrets,
      fees: _fees,
      custody: _custody,
      client: client,
      sourceWalletId: sourceWalletId,
    );
    _actor = actor;
    return actor;
  }

  /// Setup/lifecycle only: the actor obtains fresh native source evidence itself.
  Future<Result<void, ArkFailure>> reconcileSource(String operationId) {
    final actor = _actor;
    if (_closed || actor == null) {
      return Future.value(const Err(ArkServiceUnavailableFailure()));
    }
    return actor.reconcileSource(operationId);
  }

  /// The root then closes its client/runtime/authority, in that order.
  Future<void> close() async {
    _closed = true;
    await _actor?.close();
  }
}
