import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/widgets.dart' show StreamBuilder;
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import '../data/ark_operation_id.dart';
import '../data/ark_repository_impl.dart';
import '../data/create_ark_facade.dart';
import '../domain/ark_account_selection_port.dart';
import '../domain/ark_board_funding_port.dart';
import '../domain/ark_display_data_port.dart';
import '../domain/ark_exit_destination_port.dart';
import '../domain/ark_exit_funding.dart';
import '../domain/usecases/read_ark_exit_destination_usecase.dart';
import '../domain/usecases/read_ark_display_data_usecase.dart';
import '../domain/usecases/read_ark_next_round_usecase.dart';
import '../presentation/ark_next_round_cubit.dart';
import '../presentation/ark_display_data_cubit.dart';
import '../domain/ark_provisioning_port.dart';
import '../domain/repositories/ark_account_registry_repository.dart';
import '../domain/repositories/ark_repository.dart';
import '../domain/usecases/load_ark_settings_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/usecases/read_ark_payment_animations_usecase.dart';

import 'package:preferences/preferences.dart'
    show PaymentAnimationPreferencesReader;

import '../domain/usecases/set_ark_enabled_usecase.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';
import '../domain/usecases/create_ark_receive_usecase.dart';
import '../domain/usecases/request_ark_receive_usecase.dart';
import '../domain/usecases/review_ark_payment_usecase.dart';
import '../domain/usecases/parse_ark_destination_usecase.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
import '../domain/usecases/read_ark_board_minimum_usecase.dart';
import '../domain/usecases/read_ark_board_usecase.dart';
import '../domain/usecases/confirm_ark_board_usecase.dart';
import '../presentation/ark_cubit.dart';
import '../presentation/ark_settings_cubit.dart';
import '../presentation/ark_payment_cubit.dart';
import '../presentation/ark_receive_cubit.dart';
import '../presentation/ark_operation_cubit.dart';
import '../presentation/ark_board_cubit.dart';
import '../presentation/ark_l10n.dart';
import '../ui/ark_settings_screen.dart';
import '../ui/ark_account_screen.dart';
import '../ui/ark_payment_screen.dart';
import '../ui/ark_scanner.dart';
import '../ui/ark_receive_screen.dart';
import '../ui/ark_exit_start_sheet.dart';
import '../ui/ark_renew_sheet.dart';
import '../ui/ark_vtxos_screen.dart';
import '../ui/ark_information_screen.dart';
import '../ui/ark_exits_screen.dart';
import '../ui/ark_exit_request_screen.dart';
import '../ui/ark_operation_review_screen.dart';
import '../ui/ark_snapshot_page.dart';
import '../ui/ark_unavailable_screen.dart';
import '../ui/ark_board_screen.dart';
import '../ui/ark_movement_details_screen.dart';
import 'ark_facade.dart';
import 'ark_transfer_facade.dart';
import 'ark_navigation.dart';

enum _Kind {
  settings,
  account,
  payment,
  receive,
  vtxos,
  info,
  exits,
  review,
  board,
  exitRequest,
}

const _paths = {
  _Kind.settings: '/ark',
  _Kind.account: '/ark/account',
  _Kind.payment: '/ark/pay',
  _Kind.receive: '/ark/receive',
  _Kind.vtxos: '/ark/vtxos',
  _Kind.info: '/ark/info',
  _Kind.exits: '/ark/exits',
  _Kind.review: '/ark/review',
  _Kind.board: '/ark/board',
  _Kind.exitRequest: '/ark/exit-request',
};
Object _configuration(ArkAccountConfig c) => (
  c.id,
  c.arkUrl,
  c.primaryEsploraUrl,
  c.fallbackEsploraUrl,
  c.renewalThresholdBlocks,
);
void _observeCleanup(Future<void> cleanup) {
  unawaited(
    cleanup.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        Zone.current.handleUncaughtError(error, stack);
      },
    ),
  );
}

/// Privileged UI composition. The real guarded client ALWAYS belongs to host.
/// Host invalidates this scope BEFORE external full-config/context replacement.
final class ArkFeature {
  final ArkAccountSelectionPort _selection;
  final ArkAccountConfig _config;
  final ArkClient _client;
  final ArkPreferencesRepository _preferences;
  final ArkProvisioningPort _provisioning;
  final ArkBoardFundingPort _boardFunding;
  final ArkDisplayDataPort? _displayData;
  final ArkExitDestinationPort? _exitDestination;
  final ArkExitFunding? _exitFunding;

  /// Sends the exit fees from Secure Bitcoin to the reserve when it is short.
  final Future<Result<ArkExitReserveFunding, ArkFailure>> Function(
    ArkQuote quote,
    String? reserveAddress,
  )?
  _fundInitialExit;
  final Future<Result<String?, ArkFailure>> Function(List<String>)?
  _savedExitDestination;
  final ArkScanner? _scanner;

  /// The host's wallet-card artwork, so the Ark wallet matches the app's
  /// other wallet cards; without it the card is a plain dark surface.
  final Widget? _walletBackground;

  /// Returns to the app's home; without it, a finished flow just closes.
  final void Function(BuildContext context)? _onHome;

  /// The app's confirmation arrow, so Ark's confirm screens match Send's.
  final Widget? _confirmIcon;
  final ReadArkPaymentAnimationsUsecase? _readPaymentAnimations;
  final ArkRepositoryImpl _repository;
  final ArkFacade facade;
  final _ownerListeners = <VoidCallback>{};
  bool _active = true;
  late final List<GoRoute> routes = List<GoRoute>.unmodifiable([
    for (final entry in _paths.entries)
      GoRoute(
        path: entry.value,
        builder: (_, state) => _ArkPage(
          key: state.pageKey,
          feature: this,
          kind: entry.key,
          entry: state.extra,
        ),
      ),
    for (final path in ['/ark/unavailable', '/ark/claim-recovery'])
      GoRoute(path: path, builder: (_, _) => const ArkUnavailableScreen()),
  ]);

  ArkFeature(
    this._selection, {
    required this._config,
    required ArkClient client,
    required ArkPreferencesRepository preferences,
    required ArkProvisioningPort provisioning,
    required ArkAccountRegistryRepository registry,
    required ArkBoardFundingPort boardFunding,
    this._displayData,
    this._scanner,
    this._walletBackground,
    this._onHome,
    this._confirmIcon,
    this._exitDestination,
    this._exitFunding,
    this._fundInitialExit,
    this._savedExitDestination,
    PaymentAnimationPreferencesReader? paymentAnimations,
  }) : _readPaymentAnimations = paymentAnimations == null
           ? null
           : ReadArkPaymentAnimationsUsecase(paymentAnimations),
       _client = client,
       _preferences = preferences,
       _provisioning = provisioning,
       _boardFunding = boardFunding,
       _repository = ArkRepositoryImpl(client),
       facade = createArkFacade(
         client: client,
         preferences: preferences,
         provisioning: provisioning,
         boardFunding: boardFunding,
         registry: registry,
       );

  /// Resolve preferences and native evidence through the existing use cases.
  Future<Result<ArkTransferContext, ArkFailure>> transferContext(
    String sourceWalletId,
  ) async {
    if (!_active) return const Err(ArkServiceUnavailableFailure());
    final settings = await _load.execute();
    if (settings case Err(:final failure)) return Err(failure);
    if (settings case Ok(value: final settings)) {
      if (!settings.enabled) return const Err(ArkDisabledFailure());
      if (_configuration(settings.config) != _configuration(_config)) {
        return const Err(ArkServiceUnavailableFailure());
      }
    }
    final result = await facade.read(_config.id);
    if (!_active) return const Err(ArkServiceUnavailableFailure());
    return result.map(
      (snapshot) => ArkTransferContext(
        config: _config,
        snapshot: snapshot,
        boardSourceWalletId: sourceWalletId,
      ),
    );
  }

  /// UI invalidation, not revocation of facade references or backend effects.
  void invalidate() {
    if (!_active) return;
    _active = false;
    final failures = <(Object, StackTrace)>[];
    for (final listener in List<VoidCallback>.of(_ownerListeners)) {
      try {
        listener();
      } catch (error, stack) {
        failures.add((error, stack));
      }
    }
    for (final (error, stack) in failures) {
      Zone.current.handleUncaughtError(error, stack);
    }
  }

  LoadArkSettingsUsecase get _load =>
      LoadArkSettingsUsecase(_ScopedSelection(this), _preferences);
}

final class _ScopedSelection implements ArkAccountSelectionPort {
  final ArkFeature feature;
  const _ScopedSelection(this.feature);
  @override
  Future<Result<ArkAccountConfig, ArkFailure>> selectedAccount() async {
    final result = await feature._selection.selectedAccount();
    if (result case Ok(:final value)
        when _configuration(value) != _configuration(feature._config)) {
      feature.invalidate();
      return const Err(ArkServiceUnavailableFailure());
    }
    return result;
  }
}

/// Private navigation origin only, never native/account/registry authority.
final class _Origin {
  final _ArkPageState page;
  final BlocBase<Object?> owner;
  final ArkSettingsReady? publication;
  final _Origin? parent;
  const _Origin(this.page, this.owner, this.publication, this.parent);
  bool get valid =>
      page._live(owner) &&
      (publication == null || identical(owner.state, publication));
  ArkSettingsCubit? get settings => switch (owner) {
    final ArkSettingsCubit settings => settings,
    _ => parent?.settings,
  };
}

final class _Entry {
  final ArkFeature feature;
  final ArkAccountConfig config;
  final _Kind kind;
  final _Origin origin;
  final ArkQuoteRequest? request;
  final List<String>? claimIds;
  bool consumed = false;
  _Entry(
    this.feature,
    this.config,
    this.kind,
    this.origin, {
    this.request,
    this.claimIds,
  });
}

class _ArkPage extends StatefulWidget {
  final ArkFeature feature;
  final _Kind kind;
  final Object? entry;
  const _ArkPage({
    super.key,
    required this.feature,
    required this.kind,
    this.entry,
  });
  @override
  State<_ArkPage> createState() => _ArkPageState();
}

class _ArkPageState extends State<_ArkPage> {
  BlocBase<Object?>? _owner;
  ArkOperationCubit? _renewOwner;
  ArkDisplayDataCubit? _displayOwner;
  ArkNextRoundCubit? _nextRoundOwner;
  StreamSubscription<ArkDisplayDataState>? _displaySubscription;
  StreamSubscription<ArkSettingsState>? _originSubscription;
  int _generation = 0;
  bool _loading = false, _enabled = false;
  _Origin? get _origin => switch (widget.entry) {
    _Entry(:final origin) => origin,
    _ => null,
  };
  bool _validEntry() =>
      widget.feature._active &&
      switch (widget.entry) {
        null => widget.kind == _Kind.settings,
        final ArkTransferPaymentEntry entry =>
          widget.kind == _Kind.review &&
              entry.account == widget.feature._config.id &&
              entry.destination.isNotEmpty &&
              entry.amount.value > BigInt.zero &&
              entry.amount.value <= BigInt.from(2100000000000000),
        final ArkTransferBoardEntry entry =>
          widget.kind == _Kind.board &&
              entry.account == widget.feature._config.id &&
              entry.sourceWalletId.isNotEmpty &&
              entry.amount.value > BigInt.zero &&
              entry.amount.value <= BigInt.from(2100000000000000),
        final ArkAccountEntry entry =>
          widget.kind == _Kind.account &&
              entry.account == widget.feature._config.id,
        final ArkPaymentEntry entry =>
          widget.kind == _Kind.payment &&
              entry.account == widget.feature._config.id,
        final _Entry entry =>
          identical(entry.feature, widget.feature) &&
              entry.kind == widget.kind &&
              entry.origin.valid &&
              _configuration(entry.config) ==
                  _configuration(widget.feature._config),
        _ => false,
      };
  bool _live(BlocBase<Object?> owner) =>
      mounted && _validEntry() && identical(owner, _owner) && !owner.isClosed;

  @override
  void initState() {
    super.initState();
    widget.feature._ownerListeners.add(_invalidated);
    unawaited(_admit());
  }

  @override
  void didUpdateWidget(_ArkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feature, widget.feature) ||
        !identical(oldWidget.feature._client, widget.feature._client) ||
        _configuration(oldWidget.feature._config) !=
            _configuration(widget.feature._config) ||
        oldWidget.kind != widget.kind ||
        !identical(oldWidget.entry, widget.entry)) {
      oldWidget.feature._ownerListeners.remove(_invalidated);
      _retire();
      widget.feature._ownerListeners.add(_invalidated);
      unawaited(_admit());
    }
  }

  void _retire() {
    ++_generation;
    final owner = _owner;
    _owner = null;
    // Closing the renew cubit also dismisses its sheet.
    final renewal = _renewOwner;
    _renewOwner = null;
    if (renewal != null && !renewal.isClosed) {
      _observeCleanup(renewal.close());
    }
    final display = _displayOwner;
    _displayOwner = null;
    final rounds = _nextRoundOwner;
    _nextRoundOwner = null;
    if (rounds != null) _observeCleanup(rounds.close());
    final displaySubscription = _displaySubscription;
    _displaySubscription = null;
    if (displaySubscription != null) {
      _observeCleanup(displaySubscription.cancel());
    }
    if (display != null) _observeCleanup(display.close());
    _loading = false;
    final subscription = _originSubscription;
    _originSubscription = null;
    if (subscription != null) _observeCleanup(subscription.cancel());
    if (owner != null && !owner.isClosed) _observeCleanup(owner.close());
  }

  void _invalidated() {
    _retire(); // Detach/close owned controller synchronously before any await.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.feature._ownerListeners.remove(_invalidated);
    _retire();
    super.dispose();
  }

  Future<void> _admit() async {
    final generation = _generation;
    if (!mounted || !_validEntry()) return;
    final feature = widget.feature;
    final repository = feature._repository;
    final account = feature._config.id;
    if (widget.kind == _Kind.settings) {
      _owner = ArkSettingsCubit(
        feature._load,
        EnableArkUsecase(
          repository,
          feature._preferences,
          feature._provisioning,
        ),
        SetArkEnabledUsecase(repository, feature._preferences),
      );
      _nextRoundOwner = ArkNextRoundCubit(ReadArkNextRoundUsecase(repository));
    } else if (widget.kind == _Kind.review) {
      final entry = widget.entry;
      final ArkQuoteRequest request;
      switch (entry) {
        case ArkTransferPaymentEntry() when !entry.consumed:
          entry.consumed = true;
          request = ArkQuoteRequest.payment(
            destination: ArkPaymentDestination(
              kind: ArkDestinationKind.bitcoin,
              value: entry.destination,
            ),
            amount: entry.amount,
          );
        case _Entry() when !entry.consumed:
          final original = entry.request;
          if (original == null) return;
          entry.consumed = true;
          request = original;
        default:
          return;
      }
      final cubit = ArkOperationCubit(
        QuoteArkOperationUsecase(repository, feature._preferences),
        ConfirmArkOperationUsecase(repository, feature._preferences),
        freshArkOperationId,
        account: account,
        request: request,
      );
      _owner = cubit;
      unawaited(cubit.load()); // Parent load BEFORE passive A child mounts.
    } else {
      if (widget.entry case ArkTransferBoardEntry entry) {
        if (entry.consumed) return;
        entry.consumed = true;
      }
      _loading = true;
      final result = await feature._load.execute();
      if (!mounted || generation != _generation || !_validEntry()) return;
      _loading = false;
      if (result case Ok(:final value)) {
        _enabled = value.enabled;
        final board = widget.kind == _Kind.board && value.enabled
            ? await _board(feature, repository)
            : null;
        if (board != null &&
            (!mounted || generation != _generation || !_validEntry())) {
          await board.close();
          return;
        }
        if ((widget.kind != _Kind.payment && widget.kind != _Kind.board) ||
            value.enabled) {
          _owner = switch (widget.kind) {
            _Kind.board when board != null => board,
            _Kind.payment => ArkPaymentCubit(
              ReviewArkPaymentUsecase(
                const ParseArkDestinationUsecase(),
                QuoteArkOperationUsecase(repository, feature._preferences),
              ),
              ConfirmArkOperationUsecase(repository, feature._preferences),
              freshArkOperationId,
              account: account,
              synchronize: SynchronizeArkUsecase(repository),
            ),
            _Kind.receive => ArkReceiveCubit(
              RequestArkReceiveUsecase(
                CreateArkReceiveUsecase(repository, feature._preferences),
              ),
              account: account,
            ),
            _ => ArkCubit(
              ReadArkUsecase(repository),
              SynchronizeArkUsecase(repository),
              account: account,
            ),
          };
        }
      }
    }
    if (!mounted || generation != _generation || !_validEntry()) return;
    switch ((_owner, widget.entry)) {
      case (ArkBoardCubit owner, ArkTransferBoardEntry entry):
        unawaited(
          owner.prepare(
            entry.amount,
            expectedSourceWalletId: entry.sourceWalletId,
          ),
        );
      default:
        break;
    }
    final displayPort = feature._displayData;
    if (displayPort != null &&
        _owner != null &&
        const {
          _Kind.account,
          _Kind.vtxos,
          _Kind.board,
          _Kind.payment,
          _Kind.receive,
          _Kind.review,
        }.contains(widget.kind)) {
      final display = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(displayPort),
        account: account,
      );
      _displayOwner = display;
      _displaySubscription = display.stream.listen((_) {
        if (mounted &&
            generation == _generation &&
            identical(display, _displayOwner)) {
          setState(() {});
        }
      });
      unawaited(display.load());
    }
    final settings = _origin?.settings;
    final own = _owner;
    if (own is ArkSettingsCubit) {
      _originSubscription = own.stream.listen((_) {
        if (mounted && generation == _generation && identical(_owner, own)) {
          setState(() {}); // Capture this publication in the parent callback.
        }
      });
    } else if (settings != null) {
      void check() {
        if (mounted && generation == _generation && !_validEntry()) {
          _invalidated();
        }
      }

      // Async notification retires UI; only parent navigation is sync-origin gated.
      _originSubscription = settings.stream.listen(
        (_) => check(),
        onDone: check,
      );
    }
    setState(() {});
  }

  void _open(
    BlocBase<Object?> owner,
    _Kind kind, {
    ArkQuoteRequest? request,
    List<String>? claimIds,
    ArkSettingsState? publication,
  }) => unawaited(
    _push(
      owner,
      kind,
      request: request,
      claimIds: claimIds,
      publication: publication,
    ),
  );

  /// Opens [kind]; completes when that page closes, or null if not opened.
  Future<Object?>? _push(
    BlocBase<Object?> owner,
    _Kind kind, {
    ArkQuoteRequest? request,
    List<String>? claimIds,
    ArkSettingsState? publication,
  }) {
    if (!_live(owner)) return null;
    if (owner is ArkSettingsCubit) {
      final settings = publication?.settings;
      if (publication is! ArkSettingsReady ||
          !identical(owner.state, publication) ||
          settings == null ||
          _configuration(settings.config) !=
              _configuration(widget.feature._config)) {
        return null;
      }
    }
    final origin = _Origin(
      this,
      owner,
      publication is ArkSettingsReady ? publication : null,
      _origin,
    );
    if (!origin.valid) return null;
    final entry = _Entry(
      widget.feature,
      widget.feature._config,
      kind,
      origin,
      request: request,
      claimIds: claimIds == null ? null : List.unmodifiable(claimIds),
    );
    final path = _paths[kind];
    return path == null ? null : context.push<Object?>(path, extra: entry);
  }

  Widget _observed(ArkCubit owner, ArkSnapshot snapshot) {
    if (!_live(owner) || snapshot.account != widget.feature._config.id) {
      return const ArkUnavailableScreen();
    }
    return switch (widget.kind) {
      _Kind.vtxos => ArkVtxosScreen(
        snapshot: snapshot,
        renewalThresholdBlocks: widget.feature._config.renewalThresholdBlocks,
        // Boarding is new money: offer it only while Ark is enabled.
        onBoard: _enabled ? () => _open(owner, _Kind.board) : null,
        onRenew: (ids) => _renew(owner, ids),
      ),
      _Kind.exitRequest => ArkExitRequestScreen(
        snapshot: snapshot,
        claimIds: switch (widget.entry) {
          _Entry(:final claimIds) => claimIds,
          _ => null,
        },
        onReview: (request) => _open(owner, _Kind.review, request: request),
        quote: _quote,
        secureBitcoinAddress: switch (widget.feature._exitDestination) {
          final destination? => () => ReadArkExitDestinationUsecase(
            destination,
          ).execute(widget.feature._config.id),
          null => null,
        },
        onStarted: (outcome) => _exitStarted(owner, outcome),
        savedDestination: widget.feature._savedExitDestination,
        fundFees: switch (widget.feature._fundInitialExit) {
          final fund? => (quote) => fund(quote, snapshot.reserveAddress),
          null => null,
        },
      ),
      _Kind.info => ArkInformationScreen(
        snapshot: snapshot,
        config: widget.feature._config,
      ),
      _ => switch (widget.feature._exitFunding) {
        final funding? => StreamBuilder<void>(
          stream: funding.changes,
          builder: (_, _) => _exits(owner, snapshot, funding.needed),
        ),
        null => _exits(owner, snapshot, null),
      },
    };
  }

  Widget _exits(ArkCubit owner, ArkSnapshot snapshot, Sats? waitingForFunds) =>
      ArkExitsScreen(
        snapshot: snapshot,
        waitingForFunds: waitingForFunds,
        readPaymentAnimations: widget.feature._readPaymentAnimations?.execute,
        onRefresh: () {
          if (_live(owner)) unawaited(owner.refresh());
        },
        // Back from a new exit, the list shows it.
        onReviewExit: () => unawaited(
          _push(owner, _Kind.exitRequest)?.then((_) {
            if (_live(owner)) unawaited(owner.refresh());
          }),
        ),
        onSendOnChain: () => _open(owner, _Kind.payment),
      );

  /// Opens the Board funded by [txid] in Ark's activity details.
  Future<void> _boardDetails(BlocBase<Object?> owner, String txid) =>
      _movementDetails(
        owner,
        (m) => m.kind == ArkMovementKind.board && m.transactionId == txid,
      );

  /// Opens the payment Ark recorded as [reference]: its movement, or the
  /// transaction it sent.
  Future<void> _paymentDetails(BlocBase<Object?> owner, String reference) =>
      _movementDetails(
        owner,
        (m) =>
            m.kind == ArkMovementKind.payment &&
            (m.id == reference || m.transactionId == reference),
      );

  /// Opens the movement [matches] picks, observed afresh when the last
  /// observation does not have it yet; leaving its details returns home,
  /// as Send's do. Not observed yet: the Ark wallet, where it will show.
  Future<void> _movementDetails(
    BlocBase<Object?> owner,
    bool Function(ArkMovement movement) matches,
  ) async {
    final feature = widget.feature;
    final account = feature._config.id;
    ArkMovement? find(Result<ArkSnapshot, ArkFailure> read) => switch (read) {
      Ok(:final value) => value.movements.where(matches).firstOrNull,
      Err() => null,
    };
    final read = ReadArkUsecase(feature._repository);
    var movement = find(await read.execute(account));
    if (movement == null) {
      await SynchronizeArkUsecase(feature._repository)
          .execute(account, renew: false);
      movement = find(await read.execute(account));
    }
    if (!_live(owner) || !mounted) return;
    final found = movement;
    if (found == null) {
      _open(owner, _Kind.account);
      return;
    }
    // Closing these details goes home directly, as Send's do.
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ArkMovementDetailsScreen(movement: found, onClose: _home),
        ),
      ),
    );
  }

  /// The app's home when the host offers one, else just this page closed.
  void _home() {
    if (!mounted) return;
    final home = widget.feature._onHome;
    if (home != null) {
      home(context);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// A quote for this account; whoever takes it loads and closes it.
  ArkOperationCubit _quote(ArkQuoteRequest request) {
    final feature = widget.feature;
    return ArkOperationCubit(
      QuoteArkOperationUsecase(feature._repository, feature._preferences),
      ConfirmArkOperationUsecase(feature._repository, feature._preferences),
      freshArkOperationId,
      account: feature._config.id,
      request: request,
    );
  }

  /// Back to the exits list, which refreshes to show the new exit.
  void _exitStarted(BlocBase<Object?> owner, ArkExitOutcome outcome) {
    if (!_live(owner) || !mounted) return;
    final l10n = arkLocalizationsOf(context);
    BullSnackBar.show(
      context,
      message: switch (outcome) {
        ArkExitOutcome.started => l10n.operationExitStarted,
        ArkExitOutcome.uncertain => l10n.uncertain,
      },
    );
    Navigator.pop(context);
  }

  /// Reviews a renewal in a sheet over the VTXO details. The sheet's cubit
  /// lives only as long as the sheet; a started or uncertain renewal
  /// refreshes the observed account.
  /// True once a renewal started, or may have.
  Future<bool> _renew(ArkCubit owner, List<String> ids) async {
    if (!_live(owner) || _renewOwner != null) return false;
    final feature = widget.feature;
    final cubit = ArkOperationCubit(
      QuoteArkOperationUsecase(feature._repository, feature._preferences),
      ConfirmArkOperationUsecase(feature._repository, feature._preferences),
      freshArkOperationId,
      account: feature._config.id,
      request: ArkQuoteRequest.renewal(ids: ids),
    );
    _renewOwner = cubit;
    unawaited(cubit.load());
    final price = switch (_displayOwner?.state) {
      ArkDisplayDataReady(:final source) when source.account == cubit.account =>
        source.price,
      _ => null,
    };
    final outcome = await ArkRenewSheet.show(
      context,
      cubit: cubit,
      price: price,
    );
    if (identical(_renewOwner, cubit)) _renewOwner = null;
    await cubit.close();
    if (outcome == null || !_live(owner) || !mounted) return false;
    final l10n = arkLocalizationsOf(context);
    BullSnackBar.show(
      context,
      message: switch (outcome) {
        ArkRenewOutcome.started => l10n.operationRenewalStarted,
        ArkRenewOutcome.uncertain => l10n.uncertain,
      },
    );
    unawaited(owner.refresh());
    return true;
  }

  Future<String?> _scanPayment() async {
    final owner = _owner;
    final scanner = widget.feature._scanner;
    if (owner is! ArkPaymentCubit || scanner == null || !_live(owner)) {
      return null;
    }
    final value = await scanner(context, context.loc.send);
    return _live(owner) ? value : null;
  }

  Sats? _observedSpendable() {
    var origin = _origin;
    while (origin != null) {
      if (!origin.valid) return null;
      final owner = origin.owner;
      if (owner is ArkCubit) {
        if (owner.state case ArkObserved(:final snapshot)
            when snapshot.account == widget.feature._config.id &&
                !snapshot.stale) {
          return snapshot.spendable;
        }
      }
      origin = origin.parent;
    }
    return null;
  }

  Future<ArkBoardCubit> _board(
    ArkFeature feature,
    ArkRepository repository,
  ) async {
    final cubit = ArkBoardCubit(
      PrepareArkBoardUsecase(feature._boardFunding, feature._preferences),
      ReadArkBoardUsecase(feature._boardFunding),
      ConfirmArkBoardUsecase(feature._boardFunding, feature._preferences),
      ReadArkBoardMinimumUsecase(repository),
      config: feature._config,
    );
    await cubit.loadMinimum();
    return cubit;
  }

  @override
  Widget build(BuildContext context) {
    if (!_validEntry()) return const ArkUnavailableScreen();
    final owner = _owner;
    final publication = owner is ArkSettingsCubit ? owner.state : null;
    final displayData = switch (_displayOwner?.state) {
      ArkDisplayDataReady(:final source)
          when source.account == widget.feature._config.id =>
        source,
      _ => null,
    };
    return switch (owner) {
      ArkSettingsCubit() => ArkSettingsScreen(
        cubit: owner,
        onInfo: () => _open(owner, _Kind.info, publication: publication),
        onVtxos: () => _open(owner, _Kind.vtxos, publication: publication),
        onBoard: () {
          if (publication is ArkSettingsReady &&
              publication.settings?.enabled == true) {
            _open(owner, _Kind.board, publication: publication);
          }
        },
        onExits: () => _open(owner, _Kind.exits, publication: publication),
        onOpenAccount: (_) =>
            _open(owner, _Kind.account, publication: publication),
        nextRound: _nextRoundOwner,
      ),
      ArkPaymentCubit() => ArkPaymentScreen(
        cubit: owner,
        displayData: displayData,
        observedSpendable: _observedSpendable(),
        onScan: widget.feature._scanner == null ? null : _scanPayment,
        initialDestination: switch (widget.entry) {
          ArkPaymentEntry(:final destination) => destination,
          _ => '',
        },
        onReconcile: () => _open(owner, _Kind.vtxos),
        // A finished payment returns home, wherever it was started from.
        onHome: _home,
        onViewDetails: (reference) =>
            unawaited(_paymentDetails(owner, reference)),
        confirmIcon: widget.feature._confirmIcon,
        readPaymentAnimations: widget.feature._readPaymentAnimations?.execute,
      ),
      ArkReceiveCubit() => ArkReceiveScreen(
        cubit: owner,
        displayData: displayData,
      ),
      ArkBoardCubit() => ArkBoardScreen(
        cubit: owner,
        displayData: displayData,
        onReconcile: () => _open(owner, _Kind.vtxos),
        onViewDetails: (txid) => unawaited(_boardDetails(owner, txid)),
        onClose: _home,
        confirmIcon: widget.feature._confirmIcon,
        readPaymentAnimations: widget.feature._readPaymentAnimations?.execute,
      ),
      ArkOperationCubit() => ArkOperationReviewScreen(
        cubit: owner,
        displayData: displayData,
        onReconcile: () => _open(
          owner,
          owner.request is ArkEmergencyExitQuoteRequest ||
                  owner.request is ArkExitProgressQuoteRequest ||
                  owner.request is ArkClaimQuoteRequest
              ? _Kind.exits
              : _Kind.vtxos,
        ),
      ),
      ArkCubit() when widget.kind == _Kind.account => ArkAccountScreen(
        cubit: owner,
        displayData: displayData,
        enabled: _enabled,
        walletBackground: widget.feature._walletBackground,
        onSend: () => _open(owner, _Kind.payment),
        onReceive: () => _open(owner, _Kind.receive),
        onVtxos: () => _open(owner, _Kind.vtxos),
        // Settings is a root entry: it carries no origin, account or quote.
        onSettings: () {
          if (_live(owner)) ArkNavigation.open(context);
        },
      ),
      ArkCubit() => ArkSnapshotPage(
        cubit: owner,
        builder: (snapshot) => _observed(owner, snapshot),
      ),
      // Bull's loading cubes while Ark opens, as elsewhere in the app.
      _ when _loading => const BullScaffold(
        body: Center(child: BullLoader.large()),
      ),
      _ => const ArkUnavailableScreen(),
    };
  }
}
