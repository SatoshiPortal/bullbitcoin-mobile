import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import '../data/ark_operation_id.dart';
import '../data/ark_repository_impl.dart';
import '../data/create_ark_facade.dart';
import '../domain/ark_account_selection_port.dart';
import '../domain/ark_board_funding_port.dart';
import '../domain/ark_display_data_port.dart';
import '../domain/ark_board_source_port.dart';
import '../domain/usecases/refresh_ark_board_source_usecase.dart';
import '../domain/usecases/read_ark_display_data_usecase.dart';
import '../presentation/ark_display_data_cubit.dart';
import '../domain/ark_provisioning_port.dart';
import '../domain/repositories/ark_account_registry_repository.dart';
import '../domain/usecases/load_ark_settings_usecase.dart';
import '../domain/usecases/read_ark_usecase.dart';
import '../domain/usecases/enable_ark_usecase.dart';
import '../domain/usecases/set_ark_enabled_usecase.dart';
import '../domain/usecases/quote_ark_operation_usecase.dart';
import '../domain/usecases/confirm_ark_operation_usecase.dart';
import '../domain/usecases/create_ark_receive_usecase.dart';
import '../domain/usecases/request_ark_receive_usecase.dart';
import '../domain/usecases/review_ark_payment_usecase.dart';
import '../domain/usecases/parse_ark_destination_usecase.dart';
import '../domain/usecases/prepare_ark_board_usecase.dart';
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
import '../ui/ark_vtxos_screen.dart';
import '../ui/ark_information_screen.dart';
import '../ui/ark_exits_screen.dart';
import '../ui/ark_exit_request_screen.dart';
import '../ui/ark_operation_review_screen.dart';
import '../ui/ark_snapshot_page.dart';
import '../ui/ark_unavailable_screen.dart';
import '../ui/ark_board_screen.dart';
import '../ui/ark_exit_progress_fee_screen.dart';
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
  progressFee,
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
  _Kind.progressFee: '/ark/exit-progress',
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
  final ArkBoardSourcePort? _boardSource;
  final ArkScanner? _scanner;
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
    this._boardSource,
    this._scanner,
  }) : _client = client,
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
  ArkDisplayDataCubit? _displayOwner;
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
  bool get _ordinaryBoard =>
      widget.kind == _Kind.board && widget.entry is! ArkTransferBoardEntry;

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
    final display = _displayOwner;
    _displayOwner = null;
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
        if ((widget.kind != _Kind.payment && widget.kind != _Kind.board) ||
            value.enabled) {
          _owner = switch (widget.kind) {
            _Kind.board => ArkBoardCubit(
              PrepareArkBoardUsecase(
                feature._boardFunding,
                feature._preferences,
              ),
              ReadArkBoardUsecase(feature._boardFunding),
              ConfirmArkBoardUsecase(
                feature._boardFunding,
                feature._preferences,
              ),
              config: feature._config,
            ),
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
    final boardSource = _ordinaryBoard ? feature._boardSource : null;
    final displayPort = boardSource ?? feature._displayData;
    if (displayPort != null &&
        _owner != null &&
        const {
          _Kind.account,
          _Kind.board,
          _Kind.payment,
          _Kind.receive,
          _Kind.review,
        }.contains(widget.kind)) {
      final display = ArkDisplayDataCubit(
        ReadArkDisplayDataUsecase(displayPort),
        account: account,
        refresh: boardSource == null
            ? null
            : RefreshArkBoardSourceUsecase(boardSource),
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
  }) {
    if (!_live(owner)) return;
    if (owner is ArkSettingsCubit) {
      final settings = publication?.settings;
      if (publication is! ArkSettingsReady ||
          !identical(owner.state, publication) ||
          settings == null ||
          _configuration(settings.config) !=
              _configuration(widget.feature._config)) {
        return;
      }
    }
    final origin = _Origin(
      this,
      owner,
      publication is ArkSettingsReady ? publication : null,
      _origin,
    );
    if (!origin.valid) return;
    final entry = _Entry(
      widget.feature,
      widget.feature._config,
      kind,
      origin,
      request: request,
      claimIds: claimIds == null ? null : List.unmodifiable(claimIds),
    );
    final path = _paths[kind];
    if (path != null) unawaited(context.push(path, extra: entry));
  }

  Widget _observed(ArkCubit owner, ArkSnapshot snapshot) {
    if (!_live(owner) || snapshot.account != widget.feature._config.id) {
      return const ArkUnavailableScreen();
    }
    final publication = owner.state;
    return switch (widget.kind) {
      _Kind.vtxos => ArkVtxosScreen(
        snapshot: snapshot,
        onBoard:
            _enabled &&
                publication is ArkObserved &&
                identical(publication.snapshot, snapshot)
            ? () {
                if (_live(owner) &&
                    _enabled &&
                    identical(owner.state, publication)) {
                  _open(owner, _Kind.board);
                }
              }
            : null,
        onRenew: (ids) {
          if (_live(owner)) {
            _open(
              owner,
              _Kind.review,
              request: ArkQuoteRequest.renewal(ids: ids),
            );
          }
        },
      ),
      _Kind.exitRequest => ArkExitRequestScreen(
        snapshot: snapshot,
        claimIds: switch (widget.entry) {
          _Entry(:final claimIds) => claimIds,
          _ => null,
        },
        onReview: (request) => _open(owner, _Kind.review, request: request),
      ),
      _Kind.info => ArkInformationScreen(
        snapshot: snapshot,
        config: widget.feature._config,
      ),
      _ => ArkExitsScreen(
        snapshot: snapshot,
        onRefresh: () {
          if (_live(owner)) unawaited(owner.refresh());
        },
        onReviewExit: () => _open(owner, _Kind.exitRequest),
        onReviewProgress: () => _open(owner, _Kind.progressFee),
        onReviewClaim: (ids) => _open(owner, _Kind.exitRequest, claimIds: ids),
      ),
    };
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

  @override
  Widget build(BuildContext context) {
    if (!_validEntry()) return const ArkUnavailableScreen();
    final owner = _owner;
    final publication = owner is ArkSettingsCubit ? owner.state : null;
    final displayOwner = _displayOwner;
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
      ),
      ArkReceiveCubit() => ArkReceiveScreen(
        cubit: owner,
        displayData: displayData,
      ), // Share honestly absent.
      ArkBoardCubit() => ArkBoardScreen(
        cubit: owner,
        onSourceEntry: !_ordinaryBoard || widget.feature._boardSource == null
            ? null
            : () async {
                if (_live(owner) &&
                    owner.state is ArkBoardEditing &&
                    identical(displayOwner, _displayOwner)) {
                  await displayOwner?.refreshSource();
                }
              },
        onRefreshSource: !_ordinaryBoard || widget.feature._boardSource == null
            ? null
            : () {
                if (_live(owner) &&
                    owner.state is ArkBoardEditing &&
                    identical(displayOwner, _displayOwner)) {
                  unawaited(displayOwner?.refreshSource() ?? Future.value());
                }
              },
        sourceReady: !_ordinaryBoard || widget.feature._boardSource == null
            ? null
            : () =>
                  _live(owner) &&
                  owner.state is ArkBoardEditing &&
                  identical(displayOwner, _displayOwner) &&
                  (displayOwner?.accepts(displayData) ?? false),
        displayData: displayData,
        onReconcile: () => _open(owner, _Kind.vtxos),
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
        onSend: () => _open(owner, _Kind.payment),
        onReceive: () => _open(owner, _Kind.receive),
        onBoard: () => _open(owner, _Kind.board),
        onVtxos: () => _open(owner, _Kind.vtxos),
        onExits: () => _open(owner, _Kind.exits),
        onInfo: () => _open(owner, _Kind.info),
      ),
      ArkCubit() when widget.kind == _Kind.progressFee =>
        ArkExitProgressFeeScreen(
          config: widget.feature._config,
          onReviewRequest: (config, rate) {
            if (_live(owner) && identical(config, widget.feature._config)) {
              _open(
                owner,
                _Kind.review,
                request: ArkQuoteRequest.exitProgress(feeRate: rate),
              );
            }
          },
        ),
      ArkCubit() => ArkSnapshotPage(
        cubit: owner,
        builder: (snapshot) => _observed(owner, snapshot),
      ),
      _ when _loading => BullScaffold(
        body: Center(
          child: BullText(arkLocalizationsOf(context).loading, style: null),
        ),
      ),
      _ => const ArkUnavailableScreen(),
    };
  }
}
