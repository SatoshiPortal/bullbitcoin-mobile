import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class PosSettlementDescriptor {
  const PosSettlementDescriptor({
    required this.ctDescriptor,
    required this.descriptorFingerprint,
    required this.terminalBranch,
  });

  final String ctDescriptor;
  final String descriptorFingerprint;
  final int terminalBranch;
}

abstract class PosSettlementDescriptorPort {
  Future<PosSettlementDescriptor> descriptorForTerminal({
    required Wallet wallet,
    required int terminalIndex,
  });
}
