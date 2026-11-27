import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/default_wallets_state.dart';
import '../domain/default_wallets_event.dart';
import '../domain/default_wallets_effect.dart';
import '../domain/usecases/get_default_wallets_usecase.dart';
import '../domain/usecases/save_default_wallet_usecase.dart';
import '../domain/usecases/unset_default_wallet_usecase.dart';
import '../domain/usecases/validate_default_wallet_destination_usecase.dart';
import '../domain/usecases/verify_default_wallets_usecase.dart';

/// Runs one effect of [DefaultWalletsState.next] through its use case and
/// answers with the event that carries its result and the attempt that
/// started it.
Future<DefaultWalletsEvent> runDefaultWalletsEffect(
  DefaultWalletsEffect effect, {
  required GetDefaultWalletsUsecase getWallets,
  required ValidateDefaultWalletDestinationUsecase validateAddress,
  required SaveDefaultWalletUsecase saveWallet,
  required UnsetDefaultWalletUsecase unsetWallet,
  required VerifyDefaultWalletsUsecase verifyWallets,
}) async => switch (effect) {
  FetchDefaultWallets(:final session, :final attempt) => WalletsLoaded(
    attempt,
    await getWallets.execute(session),
  ),
  CheckWalletAddress(:final network, :final attempt, :final text) =>
    SlotChecked(network, attempt, await validateAddress.execute(network, text)),
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
      await saveWallet.execute(
        session,
        network: network,
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
      await unsetWallet.execute(
        session,
        network: network,
        recipientId: recipientId,
        address: address,
      ),
    ),
  VerifyDefaultWallets(:final session, :final network, :final attempt) =>
    SlotVerified(network, attempt, await verifyWallets.execute(session)),
};

/// Shell of [DefaultWalletsState.next]: one event at a time, emits the next
/// state, starts its effects. Results arriving after close are dropped.
class DefaultWalletsBloc
    extends Bloc<DefaultWalletsEvent, DefaultWalletsState> {
  DefaultWalletsBloc({
    required ExchangeSession? session,
    required GetDefaultWalletsUsecase getWallets,
    required ValidateDefaultWalletDestinationUsecase validateAddress,
    required SaveDefaultWalletUsecase saveWallet,
    required UnsetDefaultWalletUsecase unsetWallet,
    required VerifyDefaultWalletsUsecase verifyWallets,
  }) : this._(
         defaultWalletsStart(session),
         getWallets,
         validateAddress,
         saveWallet,
         unsetWallet,
         verifyWallets,
       );

  DefaultWalletsBloc._(
    DefaultWalletsNext start,
    this._getWallets,
    this._validateAddress,
    this._saveWallet,
    this._unsetWallet,
    this._verifyWallets,
  ) : super(start.state) {
    on<DefaultWalletsEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final GetDefaultWalletsUsecase _getWallets;
  final ValidateDefaultWalletDestinationUsecase _validateAddress;
  final SaveDefaultWalletUsecase _saveWallet;
  final UnsetDefaultWalletUsecase _unsetWallet;
  final VerifyDefaultWalletsUsecase _verifyWallets;

  void _onEvent(DefaultWalletsEvent event, Emitter<DefaultWalletsState> emit) {
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<DefaultWalletsEffect> effects) {
    for (final effect in effects) {
      unawaited(
        runDefaultWalletsEffect(
          effect,
          getWallets: _getWallets,
          validateAddress: _validateAddress,
          saveWallet: _saveWallet,
          unsetWallet: _unsetWallet,
          verifyWallets: _verifyWallets,
        ).then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }
}
