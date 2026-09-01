import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/forget_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/prepare_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/scan_passphrase_wallet_balance_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/unlock_known_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/update_passphrase_wallet_metadata_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_state.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

enum PassphraseWalletEntryStatus { openedKnown, newWallet }

/// What one submitted passphrase turned out to be, so the page can run the
/// approved disclaimer sequence for a new wallet and skip it for a known one
/// (spec 6.7).
final class PassphraseWalletEntryResult {
  final PassphraseWalletEntryStatus status;
  final bool hasHistory;

  const PassphraseWalletEntryResult({
    required this.status,
    this.hasHistory = false,
  });
}

/// The Passphrase page's only state owner (spec F20, F24).
///
/// It holds the page's whole state, including which wallet is loaded, which it
/// reads from the wallet feature's published catalog rather than letting the
/// widgets ask a session object while they build. The candidate private
/// material of an entry in progress lives in a private field here and never in
/// [PassphraseWalletState] (spec 20.3).
final class PassphraseWalletCubit extends Cubit<PassphraseWalletState> {
  final GetPassphraseWalletsUsecase _getWallets;
  final PreparePassphraseWalletUsecase _prepare;
  final UnlockKnownPassphraseWalletUsecase _unlockKnown;
  final CreatePassphraseWalletUsecase _createNew;
  final ForgetPassphraseWalletUsecase _forgetWallet;
  final UpdatePassphraseWalletMetadataUsecase _updateMetadata;
  final ScanPassphraseWalletBalanceUsecase _scanBalance;
  final WalletFacade _wallets;

  StreamSubscription<List<Wallet>>? _catalog;
  PassphraseWalletPreparation? _pending;
  PassphraseWalletPreparation? _active;
  int? _pendingMountGeneration;
  var _entryGeneration = 0;

  /// Bumped by every page load and by close, so results from a scan or a load
  /// the user has already left behind are dropped (spec 6.4).
  var _generation = 0;

  PassphraseWalletCubit(
    this._getWallets,
    this._prepare,
    this._unlockKnown,
    this._createNew,
    this._forgetWallet,
    this._updateMetadata,
    this._scanBalance,
    this._wallets,
  ) : super(const PassphraseWalletState()) {
    _catalog = _wallets.watchVisibleWalletCatalog().listen(_onCatalogChanged);
  }

  /// Reads the page's wallets, then scans each locked descriptor once.
  ///
  /// This is the only automatic balance scan in the app: entering the page runs
  /// it, and nothing else does (spec 6.4).
  Future<void> load() async {
    final generation = ++_generation;
    emit(state.copyWith(status: PassphraseWalletLoadStatus.loading));
    switch (await _getWallets.execute()) {
      case Err(:final failure):
        if (_stale(generation)) return;
        emit(
          state.copyWith(
            status: PassphraseWalletLoadStatus.failure,
            failure: failure,
          ),
        );
      case Ok(:final value):
        if (_stale(generation)) return;
        emit(
          PassphraseWalletState(
            status: PassphraseWalletLoadStatus.success,
            wallets: [
              for (final wallet in value)
                PassphraseWalletCardState(wallet: wallet),
            ],
            loadedWalletId: _loadedAmong(value),
            isEntering: state.isEntering,
            isSubmitting: state.isSubmitting,
          ),
        );
        for (final wallet in value) {
          if (_stale(generation)) return;
          await _scan(wallet.walletId, generation);
        }
    }
  }

  Future<void> retryBalance(String walletId) => _scan(walletId, _generation);

  void startEntering() => emit(state.copyWith(isEntering: true));

  /// Creating another passphrase wallet unloads the current one first, so the
  /// user is never entering a second passphrase while a first wallet is live
  /// (spec 6.8).
  void startCreatingAnother() {
    _cancelEntryAttempt();
    _wallets.unloadPrivateWalletSession();
    emit(state.copyWith(isEntering: true));
  }

  /// Takes the entered passphrase, and either opens the wallet it already knows
  /// or reports that the page must confirm a new one.
  Future<Result<PassphraseWalletEntryResult, PassphraseWalletFailure>>
  submitPassphrase(String passphrase) async {
    _clearPending();
    final entryGeneration = ++_entryGeneration;
    final mountGeneration = _wallets.beginPassphraseWalletMount();
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final prepared = await _prepare.execute(passphrase);
    final PassphraseWalletPreparation preparation;
    switch (prepared) {
      case Ok(:final value):
        preparation = value;
      case Err(:final failure):
        if (_entryStale(entryGeneration)) {
          return const Err(PassphraseWalletConflictFailure());
        }
        _wallets.cancelPassphraseWalletMount();
        _endEntry();
        return Err(failure);
    }
    if (_entryStale(entryGeneration)) {
      preparation.clear();
      return const Err(PassphraseWalletConflictFailure());
    }

    if (!preparation.isKnown) {
      // Held until the page confirms or discards it; every one of those paths
      // goes back through this Cubit, which is what clears the material.
      _pending = preparation;
      _pendingMountGeneration = mountGeneration;
      return Ok(
        PassphraseWalletEntryResult(
          status: PassphraseWalletEntryStatus.newWallet,
          hasHistory: preparation.hasHistory,
        ),
      );
    }

    _active = preparation;
    late final Result<void, PassphraseWalletFailure> opened;
    try {
      opened = await _unlockKnown.execute(
        preparation,
        mountGeneration: mountGeneration,
      );
    } finally {
      if (identical(_active, preparation)) _active = null;
    }
    if (_entryStale(entryGeneration)) {
      return const Err(PassphraseWalletConflictFailure());
    }
    switch (opened) {
      case Ok():
        _endEntry(closeInput: true);
        return const Ok(
          PassphraseWalletEntryResult(
            status: PassphraseWalletEntryStatus.openedKnown,
          ),
        );
      case Err(:final failure):
        _endEntry();
        return Err(failure);
    }
  }

  Future<Result<PassphraseWalletOpenStatus, PassphraseWalletFailure>>
  confirmNewWallet({String? label, String? hint}) async {
    final pending = _pending;
    final mountGeneration = _pendingMountGeneration;
    if (pending == null || pending.isKnown || mountGeneration == null) {
      _cancelEntryAttempt();
      _endEntry();
      return const Err(PassphraseWalletConflictFailure());
    }
    final entryGeneration = _entryGeneration;
    _pending = null;
    _pendingMountGeneration = null;
    _active = pending;
    late final Result<PassphraseWalletOpenStatus, PassphraseWalletFailure>
    result;
    try {
      result = await _createNew.execute(
        pending,
        mountGeneration: mountGeneration,
        label: label,
        hint: hint,
      );
    } finally {
      if (identical(_active, pending)) _active = null;
    }
    if (_entryStale(entryGeneration)) return result;
    // A wallet that was saved but could not be opened leaves the input where it
    // was: the user's next move is to unlock it, from this same page.
    _endEntry(
      closeInput: switch (result) {
        Ok(:final value) => value == PassphraseWalletOpenStatus.opened,
        Err() => false,
      },
    );
    return result;
  }

  /// Abandons the wallet the user was about to create — Edit passphrase, or a
  /// dismissed disclaimer — leaving the input open for another attempt.
  void discardCandidate() {
    _cancelEntryAttempt();
    if (isClosed) return;
    emit(state.copyWith(isSubmitting: false));
  }

  /// Abandons the entry entirely: the app is leaving the foreground, or the
  /// page is going away (spec 6.2).
  void cancelEntry() {
    _cancelEntryAttempt();
    if (isClosed) return;
    emit(state.copyWith(isEntering: false, isSubmitting: false));
  }

  Future<bool> updateHint(PassphraseWalletRecord wallet, String? hint) async {
    switch (await _updateMetadata.execute(
      wallet,
      hint: KeychainManifestEdit(hint),
    )) {
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure));
        return false;
      case Ok():
        if (isClosed) return true;
        final trimmed = hint?.trim();
        final stored = trimmed == null || trimmed.isEmpty ? null : trimmed;
        emit(
          state.copyWith(
            clearFailure: true,
            wallets: [
              for (final card in state.wallets)
                if (card.wallet.walletId == wallet.walletId)
                  card.copyWith(wallet: wallet.withHint(stored))
                else
                  card,
            ],
          ),
        );
        return true;
    }
  }

  /// Forgets [wallet], keeping its card when only part of that succeeded so the
  /// user can retry it (decision 6).
  Future<bool> forget(PassphraseWalletRecord wallet) async {
    switch (await _forgetWallet.execute(wallet)) {
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure));
        return false;
      case Ok():
        if (isClosed) return true;
        emit(
          state.copyWith(
            clearFailure: true,
            wallets: state.wallets
                .where((card) => card.wallet.walletId != wallet.walletId)
                .toList(growable: false),
            clearLoadedWalletId: state.isLoaded(wallet.walletId),
          ),
        );
        return true;
    }
  }

  /// The wallet feature republishes its visible catalog whenever a private
  /// capability is loaded or cleared, and a locked passphrase wallet is absent
  /// from it (spec 20.2). That makes catalog membership the published form of
  /// loaded-versus-locked, and this the page's one observer of it.
  void _onCatalogChanged(List<Wallet> catalog) {
    if (isClosed) return;
    final visible = catalog.map((wallet) => wallet.id).toSet();
    String? loaded;
    for (final card in state.wallets) {
      if (visible.contains(card.wallet.walletId)) {
        loaded = card.wallet.walletId;
        break;
      }
    }
    if (loaded == state.loadedWalletId) return;
    emit(
      state.copyWith(
        loadedWalletId: loaded,
        clearLoadedWalletId: loaded == null,
      ),
    );
  }

  String? _loadedAmong(List<PassphraseWalletRecord> wallets) => wallets
      .where((wallet) => _wallets.isPrivateWalletSessionLoaded(wallet.walletId))
      .firstOrNull
      ?.walletId;

  Future<void> _scan(String walletId, int generation) async {
    final card = state.wallets
        .where((item) => item.wallet.walletId == walletId)
        .firstOrNull;
    if (card == null || _stale(generation)) return;
    _updateCard(
      walletId,
      (item) => item.copyWith(
        balanceStatus: PassphraseWalletBalanceStatus.syncing,
        clearBalance: true,
      ),
    );
    final result = await _scanBalance.execute(card.wallet);
    if (_stale(generation)) return;
    // Applied to whatever the card is now, not to the copy this scan started
    // from: an edit made while the scan was in flight must survive it.
    _updateCard(
      walletId,
      (item) => switch (result) {
        Ok(:final value) => item.copyWith(
          balanceStatus: PassphraseWalletBalanceStatus.success,
          balance: value,
        ),
        Err() => item.copyWith(
          balanceStatus: PassphraseWalletBalanceStatus.failure,
          clearBalance: true,
        ),
      },
    );
  }

  void _updateCard(
    String walletId,
    PassphraseWalletCardState Function(PassphraseWalletCardState card) update,
  ) {
    if (isClosed) return;
    emit(
      state.copyWith(
        wallets: [
          for (final card in state.wallets)
            if (card.wallet.walletId == walletId) update(card) else card,
        ],
      ),
    );
  }

  void _endEntry({bool closeInput = false}) {
    if (isClosed) return;
    emit(
      state.copyWith(
        isSubmitting: false,
        isEntering: closeInput ? false : null,
      ),
    );
  }

  void _clearPending() {
    _pending?.clear();
    _active?.clear();
    _pending = null;
    _active = null;
    _pendingMountGeneration = null;
  }

  bool _stale(int generation) => generation != _generation || isClosed;

  bool _entryStale(int generation) =>
      generation != _entryGeneration || isClosed;

  void _cancelEntryAttempt() {
    _entryGeneration++;
    _wallets.cancelPassphraseWalletMount();
    _clearPending();
  }

  @override
  Future<void> close() {
    _generation++;
    _cancelEntryAttempt();
    unawaited(_catalog?.cancel());
    _catalog = null;
    return super.close();
  }
}
