import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';

class DecodeInvoiceUsecase {
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;

  DecodeInvoiceUsecase({
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
  }) : _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository;

  Future<Invoice> execute({
    required String invoice,
    bool isTestnet = false,
  }) async {
    try {
      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

      return await swapRepository.decodeInvoice(invoice: invoice);
    } catch (e) {
      throw e.toString();
    }
  }
}
