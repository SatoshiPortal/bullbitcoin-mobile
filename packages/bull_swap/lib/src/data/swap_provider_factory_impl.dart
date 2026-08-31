import 'package:bull_swap/src/data/swap_provider_factory.dart';
import 'package:bull_swap/src/domain/swap_provider.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';
import 'package:bull_swap/src/domain/swap_provider_kind.dart';

class SwapProviderFactoryImpl implements SwapProviderFactory {
  final SwapProvider Function(SwapProviderConfig config) buildBull;
  final SwapProvider Function(SwapProviderConfig config) buildBoltz;

  const SwapProviderFactoryImpl({
    required this.buildBull,
    required this.buildBoltz,
  });

  @override
  SwapProvider create(SwapProviderConfig config) => switch (config.kind) {
    SwapProviderKind.bull => buildBull(config),
    SwapProviderKind.boltz => buildBoltz(config),
  };
}
