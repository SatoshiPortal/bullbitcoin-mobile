import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

class DecodeInvoiceUsecase {
  final BoltzSwapRepository _boltzSwapRepository;

  DecodeInvoiceUsecase({required BoltzSwapRepository boltzSwapRepository})
    : _boltzSwapRepository = boltzSwapRepository;

  Future<Invoice> execute({required String invoice}) async {
    try {
      return await _boltzSwapRepository.decodeInvoice(invoice: invoice);
    } catch (e) {
      throw e.toString();
    }
  }
}
