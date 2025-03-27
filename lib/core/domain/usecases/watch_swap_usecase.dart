import 'package:bb_mobile/core/domain/entities/swap.dart';
import 'package:bb_mobile/core/domain/services/swap_watcher_service.dart';
import 'package:flutter/material.dart';

class WatchSwapUsecase {
  final SwapWatcherService _watcher;

  WatchSwapUsecase({required SwapWatcherService watcherService})
      : _watcher = watcherService;

  Stream<Swap> execute(String swapId) {
    try {
      return _watcher.swapStream.where((s) {
        debugPrint(
          '[WatchSwapUsecase] swapId: ${s.id}, swap status: ${s.status}',
        );
        return s.id == swapId;
      });
    } catch (e) {
      throw WatchSwapException(e.toString());
    }
  }
}

class WatchSwapException implements Exception {
  final String message;

  WatchSwapException(this.message);
}
