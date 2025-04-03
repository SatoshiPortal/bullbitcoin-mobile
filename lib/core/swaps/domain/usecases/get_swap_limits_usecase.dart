import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:flutter/foundation.dart';

class GetSwapLimitsUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  GetSwapLimitsUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  })  : _mainnetSwapRepository = mainnetSwapRepository,
        _testnetSwapRepository = testnetSwapRepository;

  Future<SwapLimits> execute({
    required SwapType type,
    bool isTestnet = false,
  }) async {
    try {
      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

      final swapLimits = await swapRepository.getSwapLimits(type: type);
      return swapLimits;
    } catch (e) {
      debugPrint('[GetSwapLimitsUsecase] Error getting swap limits: $e');
      throw GetSwapLimitsException(e.toString());
    }
  }
}

class GetSwapLimitsException implements Exception {
  final String message;

  GetSwapLimitsException(this.message);

  @override
  String toString() => 'GetSwapLimitsException: $message';
}
