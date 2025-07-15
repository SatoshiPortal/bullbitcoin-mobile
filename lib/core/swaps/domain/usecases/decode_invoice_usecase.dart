import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class DecodeInvoiceUsecase {
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;

  DecodeInvoiceUsecase({
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
  }) : _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository;

  Future<Invoice> execute({
    required String invoice,
    bool isTestnet = false,
  }) async {
    try {
      final swapRepository =
          isTestnet ? _testnetBoltzSwapRepository : _mainnetBoltzSwapRepository;

      return await swapRepository.decodeInvoice(invoice: invoice);
    } catch (e) {
      throw e.toString();
    }
  }
}
