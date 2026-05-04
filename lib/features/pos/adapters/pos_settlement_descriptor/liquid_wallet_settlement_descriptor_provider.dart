import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/pos/application/ports/pos_settlement_descriptor_port.dart';

class LiquidWalletSettlementDescriptorProvider
    implements PosSettlementDescriptorPort {
  const LiquidWalletSettlementDescriptorProvider();

  @override
  Future<PosSettlementDescriptor> descriptorForTerminal({
    required Wallet wallet,
    required int terminalIndex,
  }) async {
    if (!wallet.network.isLiquid) {
      throw ArgumentError('POS settlement requires a Liquid wallet.');
    }
    if (wallet.externalPublicDescriptor.isEmpty) {
      throw ArgumentError('Liquid wallet descriptor is empty.');
    }
    return PosSettlementDescriptor(
      ctDescriptor: wallet.externalPublicDescriptor,
      descriptorFingerprint: wallet.xpubFingerprint.isNotEmpty
          ? wallet.xpubFingerprint
          : wallet.masterFingerprint,
      terminalBranch: terminalIndex,
    );
  }
}
