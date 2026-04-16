import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:bb_mobile/features/samrock/domain/repositories/samrock_repository.dart';

class CompleteSamrockSetupUsecase {
  final WalletRepository _walletRepository;
  final SamrockRepository _samrockRepository;

  CompleteSamrockSetupUsecase({
    required WalletRepository walletRepository,
    required SamrockRepository samrockRepository,
  })  : _walletRepository = walletRepository,
        _samrockRepository = samrockRepository;

  Future<SamrockSetupResponse> execute(SamrockSetupRequest request) async {
    final payload = await _buildPayload(request.paymentMethods);
    return _samrockRepository.submitSetup(
      request: request,
      descriptorPayload: payload,
    );
  }

  Future<Map<String, dynamic>> _buildPayload(
    List<SamrockPaymentMethod> methods,
  ) async {
    final payload = <String, dynamic>{};

    String? btcDescriptor;
    String? liquidDescriptor;

    if (methods.contains(SamrockPaymentMethod.btc) ||
        methods.contains(SamrockPaymentMethod.lbtc) ||
        methods.contains(SamrockPaymentMethod.btcln)) {
      // Get default wallets
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
      );

      for (final wallet in defaultWallets) {
        if (wallet.isBitcoin && wallet.isDefault) {
          btcDescriptor = wallet.externalPublicDescriptor;
        }
        if (wallet.isLiquid && wallet.isDefault) {
          liquidDescriptor = wallet.externalPublicDescriptor;
        }
      }
    }

    if (methods.contains(SamrockPaymentMethod.btc)) {
      if (btcDescriptor == null || btcDescriptor.isEmpty) {
        throw Exception('No default Bitcoin wallet found');
      }
      payload['BTC'] = {
        'Descriptor': btcDescriptor,
      };
    }

    if (methods.contains(SamrockPaymentMethod.lbtc)) {
      if (liquidDescriptor == null || liquidDescriptor.isEmpty) {
        throw Exception('No default Liquid wallet found');
      }
      payload['LBTC'] = {
        'Descriptor': liquidDescriptor,
      };
    }

    if (methods.contains(SamrockPaymentMethod.btcln)) {
      if (liquidDescriptor == null || liquidDescriptor.isEmpty) {
        throw Exception('No default Liquid wallet found for Lightning setup');
      }
      payload['BTCLN'] = {
        'Type': 'Boltz',
        'LBTC': {
          'Descriptor': liquidDescriptor,
        },
      };
    }

    return payload;
  }
}
