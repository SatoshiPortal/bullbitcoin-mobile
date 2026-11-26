import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/validate_default_wallet_destination_usecase.dart';
import '../domain/default_wallets_machine.dart';

/// Runs one effect of [transitionDefaultWallets] and answers with the event
/// that carries its result and the attempt that started it.
Future<DefaultWalletsEvent> runDefaultWalletsEffect(
  DefaultWalletsEffect effect, {
  required Exchange exchange,
  required ValidateDefaultWalletDestinationUsecase validateDestination,
}) async => switch (effect) {
  FetchDefaultWallets(:final session, :final attempt) => WalletsLoaded(
    attempt,
    await exchange.readDefaultWallets(session),
  ),
  CheckWalletAddress(:final network, :final attempt, :final text) =>
    SlotChecked(
      network,
      attempt,
      await _check(validateDestination, network, text),
    ),
  SaveDefaultWallet(
    :final session,
    :final network,
    :final attempt,
    :final address,
    :final existingRecipientId,
  ) =>
    SlotSaveAnswered(
      network,
      attempt,
      await exchange.saveSessionDefaultWallet(
        session,
        walletType: network,
        address: address,
        existingRecipientId: existingRecipientId,
      ),
    ),
  UnsetDefaultWallet(
    :final session,
    :final network,
    :final attempt,
    :final recipientId,
    :final address,
  ) =>
    SlotUnsetAnswered(
      network,
      attempt,
      await exchange.unsetSessionDefaultWallet(
        session,
        recipientId: recipientId,
        walletType: network,
        address: address,
      ),
    ),
  VerifyDefaultWallets(:final session, :final network, :final attempt) =>
    SlotVerified(network, attempt, await _verify(exchange, session)),
};

Future<WalletAddressCheck> _check(
  ValidateDefaultWalletDestinationUsecase validate,
  BtcNetwork network,
  String text,
) async {
  try {
    return switch (await validate.execute(network, text)) {
      null => const WalletAddressInvalid(),
      final address => WalletAddressValid(address),
    };
  } on Exception catch (error) {
    log.warning('Failed to validate a default wallet: ${error.runtimeType}');
    return const WalletAddressCheckFailed();
  }
}

/// Settles a journaled save by re-reading (never by sending it again), then
/// reads what the exchange has.
Future<ExchangeRead<DefaultWallets>> _verify(
  Exchange exchange,
  ExchangeSession session,
) async {
  if (await exchange.reconcileUnknownWrites() case Err(:final failure)) {
    log.warning('Default wallets: journal not reconciled ($failure)');
  }
  return exchange.readDefaultWallets(session);
}

/// Shell of [transitionDefaultWallets]: one event at a time, emits the next
/// state, starts its effects. Results arriving after close are dropped.
class DefaultWalletsBloc
    extends Bloc<DefaultWalletsEvent, DefaultWalletsState> {
  DefaultWalletsBloc({
    required Exchange exchange,
    required ValidateDefaultWalletDestinationUsecase validateDestination,
  }) : this._(
         defaultWalletsStart(exchange.currentSession),
         exchange,
         validateDestination,
       );

  DefaultWalletsBloc._(
    DefaultWalletsNext start,
    this._exchange,
    this._validateDestination,
  ) : super(start.state) {
    on<DefaultWalletsEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final Exchange _exchange;
  final ValidateDefaultWalletDestinationUsecase _validateDestination;

  void _onEvent(DefaultWalletsEvent event, Emitter<DefaultWalletsState> emit) {
    final next = transitionDefaultWallets(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<DefaultWalletsEffect> effects) {
    for (final effect in effects) {
      unawaited(
        runDefaultWalletsEffect(
          effect,
          exchange: _exchange,
          validateDestination: _validateDestination,
        ).then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }
}
