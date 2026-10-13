import '../domain/entities/recoverbull_connection.dart';
import '../domain/usecases/manage_recoverbull_connection_usecase.dart';
export '../domain/entities/recoverbull_connection.dart' show KeyServerStatus;
import 'dart:async';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_provider.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/create_and_store_vault_usecase.dart';
import '../domain/usecases/decrypt_and_accept_vault_usecase.dart';
import '../domain/usecases/select_vault_usecase.dart';
import '../router/flow_type.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:bull_tor/tor.dart' as tor;

part 'bloc.mapper.dart';
part 'event.dart';
part 'state.dart';

class RecoverBullBloc extends Bloc<RecoverBullEvent, RecoverBullState> {
  final LogSink log;
  final SelectVaultUsecase _selectVault;
  final CreateAndStoreVaultUsecase _secureVault;
  final DecryptAndAcceptVaultUsecase _acceptVault;
  final ManageRecoverBullConnectionUsecase _connection;
  StreamSubscription<RecoverBullConnection>? _connectionSubscription;
  bool _closingBloc = false;
  int _connectionFailureRevision = 0;

  RecoverBullBloc({
    required this.log,
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
    required SelectVaultUsecase selectVaultUsecase,
    required CreateAndStoreVaultUsecase secureVaultUsecase,
    required DecryptAndAcceptVaultUsecase acceptVaultUsecase,
    required ManageRecoverBullConnectionUsecase connectionUsecase,
  }) : _selectVault = selectVaultUsecase,
       _secureVault = secureVaultUsecase,
       _acceptVault = acceptVaultUsecase,
       _connection = connectionUsecase,
       super(RecoverBullState(flow: flow, vault: preSelectedVault)) {
    on<OnVaultProviderSelection>(
      _onVaultProviderSelection,
      transformer: droppable(),
    );
    on<OnVaultSelection>(_onVaultSelection);
    on<OnVaultPasswordSet>(_onVaultPasswordSet, transformer: droppable());
    on<OnVaultCreation>(_onVaultCreation, transformer: droppable());
    on<OnVaultDecryption>(_onVaultDecryption, transformer: droppable());
    on<OnServerCheck>(
      (event, emit) => _connection.execute(),
      transformer: droppable(),
    );
    on<OnTorInitialization>(
      (event, emit) =>
          _connection.execute(initialize: true, restart: event.restart),
      transformer: droppable(),
    );
    on<OnClearError>(_onClearError);
    on<OnVaultKeyHidden>((event, emit) {
      emit(state.copyWith(vaultKey: null, vaultPassword: null));
    });
    on<_OnConnectionUpdated>((event, emit) {
      final next = event.state;
      final failureChanged = next.failureRevision != _connectionFailureRevision;
      _connectionFailureRevision = next.failureRevision;
      emit(
        state.copyWith(
          torConnection: next.torConnection,
          keyServerStatus: next.keyServerStatus,
          keyServerAttempt: next.keyServerAttempt,
          keyServerAttempts: next.keyServerAttempts,
          failure: failureChanged ? next.failure : state.failure,
        ),
      );
    });
    _connectionSubscription = _connection.updates.listen((next) {
      if (!_cancelled) add(_OnConnectionUpdated(next));
    });
  }

  /// Only the encrypted vault and its network are retained while a provider
  /// save is retried.
  bool get hasPendingProviderSave => _secureVault.hasPendingProviderSave;

  /// Whether a key stored for a vault abandoned before any provider save is
  /// trashed when the flow closes.
  @visibleForTesting
  bool get trashesAbandonedVaultKeys => _secureVault.trashesAbandonedVaultKeys;

  @override
  Future<void> close() async {
    _closingBloc = true;
    _secureVault.close();
    await _connectionSubscription?.cancel();
    await _connection.close();
    return super.close();
  }

  Future<void> _onVaultPasswordSet(
    OnVaultPasswordSet event,
    Emitter<RecoverBullState> emit,
  ) async {
    switch (state.flow) {
      case RecoverBullFlow.secureVault:
        if (_secureVault.hasPendingProviderSave) {
          emit(state.copyWith(failure: const VaultProviderSaveFailure()));
        } else {
          emit(state.copyWith(vaultPassword: event.password));
        }
      default:
        if (state.vault == null) {
          emit(state.copyWith(failure: const VaultNotSetFailure()));
          return;
        }
        await _onFetchVaultKey(state.vault!, event.password, emit);
    }
  }

  bool get _cancelled => isClosed || _closingBloc;

  Future<void> _onVaultProviderSelection(
    OnVaultProviderSelection event,
    Emitter<RecoverBullState> emit,
  ) async {
    log.fine(
      'recoverbull.vault.provider.selected provider=${event.provider.name}',
    );
    if (state.flow == RecoverBullFlow.secureVault) {
      await _secure(event.provider, state.vaultPassword, emit);
    } else {
      await _select(event.provider, emit);
    }
  }

  Future<void> _onVaultSelection(
    OnVaultSelection event,
    Emitter<RecoverBullState> emit,
  ) => _select(event.provider, emit);

  Future<void> _select(
    VaultProvider provider,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        failure: null,
        vault: null,
        vaultProvider: provider,
      ),
    );
    final result = await _selectVault.execute(
      provider: provider,
      cancelled: () => _cancelled,
    );
    if (_cancelled || emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(vault: value, isLoading: false));
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }

  Future<void> _onVaultCreation(
    OnVaultCreation event,
    Emitter<RecoverBullState> emit,
  ) => _secure(event.provider, event.password, emit);

  Future<void> _secure(
    VaultProvider provider,
    String? password,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        failure: null,
        vault: null,
        vaultProvider: null,
      ),
    );
    final result = await _secureVault.execute(
      provider: provider,
      password: password,
      route: _connection.route,
      onKeyStored: () {
        if (!_cancelled && !emit.isDone) {
          emit(state.copyWith(vaultPassword: null));
        }
      },
    );
    if (_cancelled || emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            vault: value.vault,
            vaultProvider: provider,
            isLoading: false,
            vaultPassword: null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isLoading: false));
    }
  }

  Future<void> _onFetchVaultKey(
    EncryptedVault vault,
    String password,
    Emitter<RecoverBullState> emit,
  ) => _accept(emit, password: password);

  Future<void> _onVaultDecryption(
    OnVaultDecryption event,
    Emitter<RecoverBullState> emit,
  ) => _accept(emit, vaultKey: event.vaultKey);

  Future<void> _accept(
    Emitter<RecoverBullState> emit, {
    String? password,
    String? vaultKey,
  }) async {
    emit(state.copyWith(isLoading: true, vaultKey: null, failure: null));
    final result = await _acceptVault.execute(
      flow: state.flow,
      vault: state.vault,
      password: password,
      vaultKey: vaultKey,
      route: _connection.route,
      cancelled: () => _cancelled,
    );
    if (_cancelled || emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            vaultKey: value.revealedKey,
            isFlowFinished: value.completed,
            isLoading: false,
            vaultPassword: null,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            failure: failure,
            vaultKey: null,
            vaultPassword: null,
            isLoading: false,
          ),
        );
    }
  }

  Future<void> _onClearError(
    OnClearError event,
    Emitter<RecoverBullState> emit,
  ) async {
    emit(state.copyWith(failure: null));
  }
}
