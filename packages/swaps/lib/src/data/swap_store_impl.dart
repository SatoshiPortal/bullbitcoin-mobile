import 'package:primitives/primitives.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';
import 'package:swaps/src/domain/swap_store.dart';
import 'package:swaps/src/util.dart' show SwapsException;

/// The swaps of one network, read from the engine's database.
class SwapStoreImpl implements SwapStore {
  final SwapStorage _storage;
  final NetworkEnv _environment;

  SwapStoreImpl({required SwapStorage storage, required NetworkEnv environment})
    : _storage = storage,
      _environment = environment {
    if ((environment == NetworkEnv.regtest) != storage.isRegtestStore ||
        environment == NetworkEnv.signet) {
      throw ArgumentError('Swap store namespace does not match its network');
    }
  }

  Future<Result<T, SwapsFailure>> _read<T>(Future<T> Function() read) async {
    try {
      return Ok(await read());
    } catch (e) {
      if (e is Error) rethrow;
      return Err(classifySwapsFailure(e));
    }
  }

  @override
  Future<Result<Swap, SwapsFailure>> get(String swapId) => _read(() async {
    final model = await _storage.fetch(swapId);
    if (model == null) throw SwapsException('swap $swapId not stored');
    return model.toEntity(environment: Environment.fromName(_environment.name));
  });

  @override
  Stream<Swap> watch(String swapId) => _storage
      .watchSwap(swapId)
      .map(
        (model) => model.toEntity(
          environment: Environment.fromName(_environment.name),
        ),
      );

  @override
  Future<Result<List<Swap>, SwapsFailure>> all({String? walletId}) => _read(
    () async {
      final models = await _storage.fetchAll(
        walletId: walletId,
        isTestnet: _environment == NetworkEnv.regtest
            ? null
            : _environment == NetworkEnv.testnet,
      );
      return [
        for (final model in models)
          model.toEntity(environment: Environment.fromName(_environment.name)),
      ];
    },
  );

  @override
  Future<Result<Swap?, SwapsFailure>> byTxId(String txId) => _read(
    () async =>
        (await _storage.fetchByTxId(txId))
            ?.toEntity(environment: Environment.fromName(_environment.name)),
  );

  @override
  Future<Result<List<Swap>, SwapsFailure>> ongoing({String? walletId}) =>
      _read(() async {
        final models = await _storage.fetchAll(
          isTestnet: _environment == NetworkEnv.regtest
              ? null
              : _environment == NetworkEnv.testnet,
        );
        return [
          for (final model in models)
            if (model.toEntity(
                  environment: Environment.fromName(_environment.name),
                )
                case final swap
                when _involves(swap, walletId) && _needsWatching(swap))
              swap,
        ];
      });

  bool _involves(Swap swap, String? walletId) =>
      walletId == null ||
      swap.walletId == walletId ||
      swap is ChainSwap && swap.receiveWalletId == walletId;

  bool _needsWatching(Swap swap) =>
      swap.status == SwapStatus.pending ||
      swap.status == SwapStatus.paid ||
      swap.hasPendingLockup ||
      swap.nextAction != SwapAction.none;
}
