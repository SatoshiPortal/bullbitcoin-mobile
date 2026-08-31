import 'package:bull_swap/src/domain/swap_provider.dart';
import 'package:bull_swap/src/domain/swap_provider_config.dart';

abstract interface class SwapProviderFactory {
  SwapProvider create(SwapProviderConfig config);
}
