import 'package:ark/ark.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';

export 'ark_facade.dart' show ArkFailure, ArkAccountConfig, ArkSnapshot;

/// A read-only publication. It grants no funding or signing authority.
final class ArkTransferContext {
  final ArkAccountConfig config;
  final ArkSnapshot snapshot;
  final String boardSourceWalletId;
  const ArkTransferContext({
    required this.config,
    required this.snapshot,
    required this.boardSourceWalletId,
  });
}

/// The foreground host resolves the current runtime on every request.
final class ArkTransferFacade {
  final Future<Result<ArkTransferContext, ArkFailure>> Function() _load;
  const ArkTransferFacade(this._load);
  @useResult
  Future<Result<ArkTransferContext, ArkFailure>> load() => _load();
}

/// Input handoff only. The wallet actor rechecks the expected source before preparing any funding operation; display metadata grants no authority.
final class ArkTransferBoardEntry {
  final ArkAccountId account;
  final String sourceWalletId;
  final Sats amount;
  bool consumed = false;
  ArkTransferBoardEntry({
    required this.account,
    required this.sourceWalletId,
    required this.amount,
  });
}

/// A cooperative payment request, always quoted natively before confirmation.
final class ArkTransferPaymentEntry {
  final ArkAccountId account;
  final String destination;
  final Sats amount;
  bool consumed = false;
  ArkTransferPaymentEntry({
    required this.account,
    required this.destination,
    required this.amount,
  });
}
