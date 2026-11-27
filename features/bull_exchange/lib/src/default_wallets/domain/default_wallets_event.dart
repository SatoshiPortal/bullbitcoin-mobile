import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'default_wallets_state.dart';

@immutable
sealed class DefaultWalletsEvent {
  const DefaultWalletsEvent();
}

final class WalletsLoaded extends DefaultWalletsEvent {
  final int attempt;
  final Result<DefaultWallets, ExchangeReadFailure> read;

  const WalletsLoaded(this.attempt, this.read);
}

final class WalletsRetryPressed extends DefaultWalletsEvent {
  const WalletsRetryPressed();
}

final class SlotTyped extends DefaultWalletsEvent {
  final BtcNetwork network;
  final String text;

  const SlotTyped(this.network, this.text);
}

final class SlotCancelPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotCancelPressed(this.network);
}

final class SlotSavePressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotSavePressed(this.network);
}

final class SlotChecked extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final WalletAddressCheck check;

  const SlotChecked(this.network, this.attempt, this.check);
}

final class SlotSaveAnswered extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>> answer;

  const SlotSaveAnswered(this.network, this.attempt, this.answer);
}

final class SlotUnsetPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotUnsetPressed(this.network);
}

final class SlotUnsetAnswered extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final GatedWrite<Result<void, ExchangeWriteFailure>> answer;

  const SlotUnsetAnswered(this.network, this.attempt, this.answer);
}

final class SlotVerified extends DefaultWalletsEvent {
  final BtcNetwork network;
  final int attempt;
  final Result<DefaultWallets, ExchangeReadFailure> read;

  const SlotVerified(this.network, this.attempt, this.read);
}

final class SlotVerifyRetryPressed extends DefaultWalletsEvent {
  final BtcNetwork network;

  const SlotVerifyRetryPressed(this.network);
}
