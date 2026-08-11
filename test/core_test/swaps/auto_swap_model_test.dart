import 'package:bb_mobile/core/swaps/data/models/auto_swap_model.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/entity/boltz_server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a Boltz fallback server between domain and persistence', () {
    final entity = AutoSwap(
      recipientWalletId: 'wallet-id',
      boltzFallbackUrl: BoltzServerUrl.parse('https://boltz.example.com'),
    );

    final model = AutoSwapModel.fromEntity(entity);
    final restored = model.toEntity();

    expect(model.boltzFallbackUrl, 'https://boltz.example.com/v2');
    expect(restored.boltzFallbackUrl, entity.boltzFallbackUrl);
  });
}
