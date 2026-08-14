import 'dart:async';
import 'dart:math';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/swap/data/datasources/exchange_public_api_datasource.dart';
import 'package:bb_mobile/features/swap/data/datasources/order_swap_local_datasource.dart';
import 'package:bb_mobile/features/swap/data/mappers/order_swap_mapper.dart';
import 'package:bb_mobile/features/swap/data/mappers/order_swap_quote_mapper.dart';
import 'package:bb_mobile/features/swap/data/mappers/order_swap_record_mapper.dart';
import 'package:bb_mobile/features/swap/data/order_swap_amount_codec.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_network.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_quote.dart';
import 'package:bb_mobile/features/swap/domain/entities/order_swap_record.dart';
import 'package:bb_mobile/features/swap/domain/repositories/order_swap_repository.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

class OrderSwapRepositoryImpl implements OrderSwapRepository {
  final ExchangePublicApiDatasource _testnetRemote;
  final ExchangePublicApiDatasource _mainnetRemote;
  final OrderSwapLocalDatasource _local;
  final DateTime Function() _now;
  final String Function() _newLocalId;
  final String Function() _newRequestId;
  final StreamController<bool> _appUpdateRequiredController =
      StreamController<bool>.broadcast(sync: true);
  Future<void> _createQueue = Future.value();
  final Map<String, Future<void>> _recordQueues = {};
  bool _isAppUpdateRequired = false;

  OrderSwapRepositoryImpl(
    this._testnetRemote,
    this._mainnetRemote,
    this._local, {
    DateTime Function()? now,
    String Function()? newLocalId,
    String Function()? newRequestId,
  }) : _now = now ?? _utcNow,
       _newLocalId = newLocalId ?? _randomLocalId,
       _newRequestId = newRequestId ?? (() => 'mobile-${_randomLocalId()}');

  @override
  bool get isAppUpdateRequired => _isAppUpdateRequired;

  @override
  Stream<bool> watchAppUpdateRequired() => _appUpdateRequiredController.stream;

  @override
  Future<Result<OrderSwapQuote, SwapFailure>> getQuote({
    required OrderSwapEnvironment environment,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) async {
    try {
      log.info(
        '[OrderSwap] quote environment=${environment.name} '
        'route=${inNetwork.name}->${outNetwork.name} '
        'amountSat=$amountSat fixedInput=$isInAmountFixed',
      );
      final model = await _remote(environment).getBestSwapOption(
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        inNetwork: inNetwork,
        outNetwork: outNetwork,
      );
      return Ok(model.toEntity(inNetwork: inNetwork, outNetwork: outNetwork));
    } catch (error) {
      final failure = _mapFailure(error);
      log.warning(
        '[OrderSwap] quote failed environment=${environment.name} '
        'route=${inNetwork.name}->${outNetwork.name} '
        'failure=${failure.runtimeType}',
      );
      return Err(failure);
    }
  }

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> createOrder({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
    required OrderSwapPurpose purpose,
    required OrderSwapEnvironment environment,
    String? sourceWalletId,
    String? destinationWalletId,
    String? note,
    BigInt? quotedCounterpartAmountSat,
  }) async {
    final previousCreate = _createQueue;
    final createCompleted = Completer<void>();
    _createQueue = createCompleted.future;
    await previousCreate;
    try {
      return await _createOrderLocked(
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        inNetwork: inNetwork,
        outNetwork: outNetwork,
        destinationAddress: destinationAddress,
        fallbackAddress: fallbackAddress,
        purpose: purpose,
        environment: environment,
        sourceWalletId: sourceWalletId,
        destinationWalletId: destinationWalletId,
        note: note,
        quotedCounterpartAmountSat: quotedCounterpartAmountSat,
      );
    } finally {
      createCompleted.complete();
    }
  }

  Future<Result<OrderSwapRecord, SwapFailure>> _createOrderLocked({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
    required OrderSwapPurpose purpose,
    required OrderSwapEnvironment environment,
    String? sourceWalletId,
    String? destinationWalletId,
    String? note,
    BigInt? quotedCounterpartAmountSat,
  }) async {
    try {
      final activeStatuses = OrderSwapLocalStatus.values
          .where((status) => !status.isTerminal)
          .map((status) => status.name);
      final matchingRow = await _local.getMatchingActiveRequest(
        purpose: purpose.name,
        environment: environment.name,
        inNetwork: inNetwork.name,
        outNetwork: outNetwork.name,
        isInAmountFixed: isInAmountFixed,
        requestedAmountSat: amountSat.toInt(),
        destination: destinationAddress,
        sourceWalletId: sourceWalletId,
        activeStatuses: activeStatuses,
      );
      if (matchingRow != null) {
        final matching = matchingRow.toEntity();
        if (matching.localStatus == OrderSwapLocalStatus.creating) {
          return const Err(
            SwapCreationUnknownFailure(
              'A matching order has an unknown creation outcome',
            ),
          );
        }
        if (matching.localStatus == OrderSwapLocalStatus.creationUnknown) {
          try {
            final order = await _createServerOrder(
              record: matching,
              amountSat: amountSat,
              isInAmountFixed: isInAmountFixed,
              inNetwork: inNetwork,
              outNetwork: outNetwork,
              destinationAddress: destinationAddress,
              fallbackAddress: fallbackAddress,
            );
            final recovered = matching.withServerOrder(
              order,
              status: OrderSwapLocalStatus.awaitingUserConfirmation,
            );
            await _saveRecordLocked(recovered);
            return Ok(recovered);
          } catch (error) {
            if (error is ArgumentError) {
              await _saveRecordLocked(matching.markFailed());
              return Err(_mapFailure(error));
            }
            return const Err(
              SwapCreationUnknownFailure(
                'A matching order has an unknown creation outcome',
              ),
            );
          }
        }
        final deadline = matching.order?.confirmationDeadline;
        final canExpireLocally =
            matching.localStatus ==
                OrderSwapLocalStatus.awaitingUserConfirmation ||
            matching.localStatus == OrderSwapLocalStatus.preparingPayin ||
            matching.localStatus == OrderSwapLocalStatus.readyToBroadcast;
        if (canExpireLocally && deadline != null && !deadline.isAfter(_now())) {
          await _saveRecordLocked(
            matching.withServerOrder(
              matching.order!,
              status: OrderSwapLocalStatus.expired,
            ),
          );
        } else {
          return Ok(matching);
        }
      }
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }

    var record = OrderSwapRecord(
      localId: _newLocalId(),
      requestId: _newRequestId(),
      purpose: purpose,
      environment: environment,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      isInAmountFixed: isInAmountFixed,
      requestedAmountSat: amountSat,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      destination: destinationAddress,
      fallback: fallbackAddress ?? destinationAddress,
      createdAt: _now(),
      localStatus: OrderSwapLocalStatus.creating,
      note: note,
      quotedCounterpartAmountSat: quotedCounterpartAmountSat,
    );

    try {
      await _saveRecordLocked(record);
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }

    try {
      log.info(
        '[OrderSwap] create request requestId=${record.requestId} '
        'route=${inNetwork.name}->${outNetwork.name} purpose=${purpose.name}',
      );
      final order = await _createServerOrder(
        record: record,
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        inNetwork: inNetwork,
        outNetwork: outNetwork,
        destinationAddress: destinationAddress,
        fallbackAddress: fallbackAddress,
      );
      final created = record.withServerOrder(
        order,
        status: OrderSwapLocalStatus.awaitingUserConfirmation,
      );
      await _saveRecordLocked(created);
      log.info(
        '[OrderSwap] create success requestId=${created.requestId} '
        'orderNumber=${order.orderNumber} '
        'orderId=${_shortOrderId(order.orderId)}',
      );
      return Ok(created);
    } catch (error) {
      log.warning(
        '[OrderSwap] create failed requestId=${record.requestId} '
        'failure=${error.runtimeType}'
        '${error is ExchangeRpcException ? ' apiCode=${error.apiCode}' : ''}',
      );
      if (_createOutcomeIsUnknown(error)) {
        try {
          await _saveRecordLocked(record.markCreationUnknown());
        } catch (storageError) {
          return Err(SwapStorageFailure(storageError.toString()));
        }
      } else if (error is ArgumentError) {
        try {
          await _saveRecordLocked(record.markFailed());
        } catch (storageError) {
          return Err(SwapStorageFailure(storageError.toString()));
        }
      } else {
        try {
          await _local.delete(record.localId);
        } catch (storageError) {
          return Err(SwapStorageFailure(storageError.toString()));
        }
      }
      return Err(_mapFailure(error));
    }
  }

  Future<OrderSwap> _createServerOrder({
    required OrderSwapRecord record,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
  }) async {
    final order = (await _remote(record.environment).createOrderSwap(
      requestId: record.requestId!,
      amountSat: amountSat,
      isInAmountFixed: isInAmountFixed,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      destinationAddress: destinationAddress,
      fallbackAddress: fallbackAddress,
    )).toEntity();
    return order;
  }

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> refreshOrder(
    String localId,
  ) async {
    try {
      final row = await _local.getByLocalId(localId);
      if (row == null) {
        return const Err(SwapOrderNotFoundFailure('Local order not found'));
      }
      final record = row.toEntity();
      final orderId = record.orderId;
      if (orderId == null) {
        return const Err(
          SwapOrderNotFoundFailure('Order has no server identifier'),
        );
      }
      final order = (await _remote(
        record.environment,
      ).getOrderSwapSummary(orderId)).toEntity();
      return await _withRecordLock(localId, () async {
        final latestRow = await _local.getByLocalId(localId);
        if (latestRow == null) {
          return const Err(SwapOrderNotFoundFailure('Local order not found'));
        }
        final latest = latestRow.toEntity();
        final refreshed = latest.withServerOrder(
          order,
          status: _updatedLocalStatus(latest, order),
          polledAt: _now(),
        );
        await _local.save(refreshed.toCompanion());
        return Ok(refreshed);
      });
    } catch (error) {
      return Err(_mapFailure(error));
    }
  }

  @override
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrders({
    String? walletId,
  }) async {
    try {
      final rows = await _local.getAll(walletId: walletId);
      return Ok(rows.map((row) => row.toEntity()).toList(growable: false));
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> getOrder(String localId) async {
    try {
      final row = await _local.getByLocalId(localId);
      if (row == null) {
        return const Err(SwapOrderNotFoundFailure('Local order not found'));
      }
      return Ok(row.toEntity());
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getPendingOrders() async {
    try {
      final terminal = OrderSwapLocalStatus.values
          .where((status) => status.isTerminal)
          .map((status) => status.name)
          .toSet();
      // Non-terminal statuses are always pollable. `failed` is terminal in
      // general, but a failed order whose payin funds already moved must
      // keep being polled until the server confirms a truthful refunded or
      // completed outcome, so it is queried too and filtered by
      // `isPollable` below.
      final pendingNames = {
        ...OrderSwapLocalStatus.values
            .map((status) => status.name)
            .where((name) => !terminal.contains(name)),
        OrderSwapLocalStatus.failed.name,
      };
      final records = <OrderSwapRecord>[];
      for (final row in await _local.getByLocalStatuses(pendingNames)) {
        var record = row.toEntity();
        if (!record.isPollable) continue;
        if (record.localStatus == OrderSwapLocalStatus.creating &&
            _now().difference(record.createdAt) >= const Duration(minutes: 1)) {
          // `createOrder` may still be actively writing this very row (e.g.
          // a slow server response). Take the same per-record lock it uses
          // and re-read the row once inside it, so this mutation is
          // conditional on the row still being `creating` at that point
          // instead of blindly overwriting whatever `createOrder` just
          // wrote (lost-update race between the periodic poller and an
          // in-flight create).
          final maybeUpdated = await _withRecordLock(record.localId, () async {
            final latestRow = await _local.getByLocalId(record.localId);
            final latest = latestRow?.toEntity();
            if (latest == null ||
                latest.localStatus != OrderSwapLocalStatus.creating) {
              return latest;
            }
            final updated = latest.markCreationUnknown();
            await _local.save(updated.toCompanion());
            return updated;
          });
          if (maybeUpdated == null) continue;
          record = maybeUpdated;
        }
        records.add(record);
      }
      return Ok(records);
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrdersAwaitingLabels({
    required OrderSwapPurpose purpose,
  }) async {
    try {
      final rows = await _local.getCompletedWithoutLabels(purpose.name);
      return Ok(rows.map((row) => row.toEntity()).toList(growable: false));
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }
  }

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> savePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _updateLocalRecord(localId, (record) {
    if (record.localStatus == OrderSwapLocalStatus.readyToBroadcast) {
      if (record.signedPayinTransaction == signedTransaction &&
          record.payinIsPsbt == isPsbt) {
        return record;
      }
      throw const _InvalidOrderSwapTransition(
        'A different signed payin is already prepared',
      );
    }
    if (record.localStatus != OrderSwapLocalStatus.awaitingUserConfirmation &&
        record.localStatus != OrderSwapLocalStatus.preparingPayin) {
      throw _InvalidOrderSwapTransition(
        'Cannot prepare a payin from ${record.localStatus.name}',
      );
    }
    return record.withPayinState(
      status: OrderSwapLocalStatus.readyToBroadcast,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
  });

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> replacePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  }) => _updateLocalRecord(localId, (record) {
    if (record.localStatus != OrderSwapLocalStatus.readyToBroadcast) {
      throw _InvalidOrderSwapTransition(
        'Cannot replace a prepared payin from ${record.localStatus.name}',
      );
    }
    if (record.signedPayinTransaction == signedTransaction &&
        record.payinIsPsbt == isPsbt) {
      return record;
    }
    return record.withPayinState(
      status: OrderSwapLocalStatus.readyToBroadcast,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
  });

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> markBroadcastUnknown(
    String localId,
  ) => _updateLocalRecord(localId, (record) {
    if (record.localStatus != OrderSwapLocalStatus.readyToBroadcast &&
        record.localStatus != OrderSwapLocalStatus.broadcastUnknown) {
      throw _InvalidOrderSwapTransition(
        'Cannot start a broadcast from ${record.localStatus.name}',
      );
    }
    if (!record.order!.confirmationDeadline.isAfter(_now())) {
      throw const _ExpiredOrderSwapTransition();
    }
    if (record.localStatus == OrderSwapLocalStatus.broadcastUnknown) {
      return record;
    }
    return record.withPayinState(status: OrderSwapLocalStatus.broadcastUnknown);
  });

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> markPayinBroadcast({
    required String localId,
    required String transactionId,
  }) => _updateLocalRecord(localId, (record) {
    if (record.localStatus == OrderSwapLocalStatus.payinBroadcast &&
        record.localPayinTransactionId == transactionId) {
      return record;
    }
    if (record.localStatus != OrderSwapLocalStatus.broadcastUnknown &&
        record.localStatus != OrderSwapLocalStatus.payoutInProgress &&
        !record.localStatus.isTerminal) {
      throw _InvalidOrderSwapTransition(
        'Cannot complete a broadcast from ${record.localStatus.name}',
      );
    }
    return record.withPayinState(
      status: record.localStatus == OrderSwapLocalStatus.broadcastUnknown
          ? OrderSwapLocalStatus.payinBroadcast
          : record.localStatus,
      transactionId: transactionId,
    );
  });

  @override
  Future<Result<OrderSwapRecord, SwapFailure>> markLabelsApplied({
    required String localId,
    required DateTime appliedAt,
  }) => _updateLocalRecord(localId, (record) {
    if (record.labelsAppliedAt != null) return record;
    if (record.localStatus != OrderSwapLocalStatus.completed) {
      throw _InvalidOrderSwapTransition(
        'Cannot apply labels to ${record.localStatus.name}',
      );
    }
    return record.withLabelsAppliedAt(appliedAt.toUtc());
  });

  @override
  Stream<Result<OrderSwapRecord, SwapFailure>> watchOrder(
    String localId,
  ) async* {
    try {
      await for (final row in _local.watchByLocalId(localId)) {
        yield Ok(row.toEntity());
      }
    } catch (error) {
      yield Err(SwapStorageFailure(error.toString()));
    }
  }

  Future<Result<OrderSwapRecord, SwapFailure>> _updateLocalRecord(
    String localId,
    OrderSwapRecord Function(OrderSwapRecord record) update,
  ) => _withRecordLock(localId, () async {
    try {
      final row = await _local.getByLocalId(localId);
      if (row == null) {
        return const Err(SwapOrderNotFoundFailure('Local order not found'));
      }
      final updated = update(row.toEntity());
      await _local.save(updated.toCompanion());
      return Ok(updated);
    } on _ExpiredOrderSwapTransition catch (error) {
      return Err(SwapOrderExpiredFailure(error.message));
    } on _InvalidOrderSwapTransition catch (error) {
      return Err(SwapInvalidStateFailure(error.message));
    } catch (error) {
      return Err(SwapStorageFailure(error.toString()));
    }
  });

  /// Persists [record] while holding its per-record lock, so this write can
  /// never interleave with a concurrent [getPendingOrders] (or any other
  /// locked mutation) racing on the same `localId`.
  Future<void> _saveRecordLocked(OrderSwapRecord record) =>
      _withRecordLock(record.localId, () => _local.save(record.toCompanion()));

  Future<T> _withRecordLock<T>(
    String localId,
    Future<T> Function() action,
  ) async {
    final previous = _recordQueues[localId] ?? Future<void>.value();
    final completed = Completer<void>();
    _recordQueues[localId] = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
      if (identical(_recordQueues[localId], completed.future)) {
        _recordQueues.remove(localId);
      }
    }
  }

  bool _createOutcomeIsUnknown(Object error) =>
      error is! ExchangeRpcException &&
      error is! ExchangeRateLimitException &&
      error is! ExchangeAppUpdateRequiredException &&
      error is! ArgumentError;

  ExchangePublicApiDatasource _remote(OrderSwapEnvironment environment) =>
      environment == OrderSwapEnvironment.testnet
      ? _testnetRemote
      : _mainnetRemote;

  OrderSwapLocalStatus _updatedLocalStatus(
    OrderSwapRecord record,
    OrderSwap order,
  ) {
    final current = record.localStatus;
    // Terminal statuses stop being re-evaluated, except a `failed` order
    // whose payin funds already moved: that failure may have been
    // provisional, so it keeps being refreshed towards a truthful
    // refunded/completed outcome instead of staying stuck as failed.
    final canLeaveFailed =
        current == OrderSwapLocalStatus.failed && record.hasFundsMoved;
    if (current.isTerminal && !canLeaveFailed) return current;
    final orderStatus = order.orderStatus.trim().toLowerCase();
    final payoutStatus = order.payoutStatus.trim().toLowerCase();
    if (payoutStatus == 'completed') return OrderSwapLocalStatus.completed;
    if (payoutStatus == 'refunded') return OrderSwapLocalStatus.refunded;
    if (payoutStatus == 'failed' ||
        payoutStatus == 'rejected' ||
        payoutStatus == 'cancelled' ||
        payoutStatus == 'canceled') {
      return OrderSwapLocalStatus.failed;
    }
    if (orderStatus == 'completed') return OrderSwapLocalStatus.completed;
    if (orderStatus == 'refunded') return OrderSwapLocalStatus.refunded;
    if (orderStatus == 'expired' || orderStatus == 'payment deadline expired') {
      return OrderSwapLocalStatus.expired;
    }
    if (orderStatus == 'failed' ||
        orderStatus == 'rejected' ||
        orderStatus == 'cancelled' ||
        orderStatus == 'canceled') {
      return OrderSwapLocalStatus.failed;
    }
    if (order.payinStatus.toLowerCase() == 'completed') {
      return OrderSwapLocalStatus.payoutInProgress;
    }
    if ((current == OrderSwapLocalStatus.awaitingUserConfirmation ||
            current == OrderSwapLocalStatus.preparingPayin ||
            current == OrderSwapLocalStatus.readyToBroadcast) &&
        !order.confirmationDeadline.isAfter(_now())) {
      return OrderSwapLocalStatus.expired;
    }
    return current;
  }

  SwapFailure _mapFailure(Object error) {
    if (error is ArgumentError) {
      return SwapOrderMismatchFailure(error.message.toString());
    }
    if (error is ExchangeRateLimitException) {
      return SwapRateLimitedFailure(
        retryAfter: error.retryAfterSeconds == null
            ? null
            : Duration(seconds: error.retryAfterSeconds!),
      );
    }
    if (error is ExchangeAppUpdateRequiredException) {
      if (!_isAppUpdateRequired) {
        _isAppUpdateRequired = true;
        _appUpdateRequiredController.add(true);
      }
      return const SwapProviderFailure('App update required');
    }
    if (error is ExchangeTimeoutException) {
      return SwapTimeoutFailure(error.logMessage);
    }
    if (error is ExchangeNetworkException) {
      return SwapNetworkFailure(error.logMessage);
    }
    if (error is ExchangeRpcException) {
      return switch (error.apiCode) {
        'ERR_ORD_PO404' => SwapNoPaymentOptionFailure(error.logMessage),
        'ERR_ORD_LMT001' => SwapAmountOutOfBoundsFailure(
          limitAmountSat: error.limit == null
              ? null
              : orderSwapAmountToSats(error.limit!),
          isMinimum: switch (error.limitOperator) {
            'greater than or equal' => true,
            'less than or equal' => false,
            _ => null,
          },
          logMessage: error.logMessage,
        ),
        'ERR_ORD_404' => SwapOrderNotFoundFailure(error.logMessage),
        'ERR_PROV_400' => SwapProviderFailure(error.logMessage),
        'ERR_API_400' ||
        'ERR_VALIDATION_ENUM' ||
        'ERR_VALIDATION_BOOLEAN' => SwapValidationFailure(
          field: error.field,
          logMessage: error.logMessage,
        ),
        _ => SwapUnexpectedFailure(error.logMessage),
      };
    }
    if (error is ExchangeResponseException || error is FormatException) {
      return SwapUnexpectedFailure(error.toString());
    }
    return SwapStorageFailure(error.toString());
  }
}

class _InvalidOrderSwapTransition implements Exception {
  final String message;

  const _InvalidOrderSwapTransition(this.message);
}

final class _ExpiredOrderSwapTransition extends _InvalidOrderSwapTransition {
  const _ExpiredOrderSwapTransition()
    : super('The swap confirmation deadline has passed');
}

DateTime _utcNow() => DateTime.now().toUtc();

String _randomLocalId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

String _shortOrderId(String orderId) =>
    orderId.substring(0, min(8, orderId.length));
