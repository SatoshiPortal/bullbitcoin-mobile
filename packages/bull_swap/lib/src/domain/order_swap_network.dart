import 'package:bull_swap/src/domain/swap_network.dart';

enum OrderSwapNetwork {
  bitcoin,
  liquid,
  lightning;

  String get apiName => name;

  static OrderSwapNetwork fromSwapNetwork(SwapNetwork network) =>
      switch (network) {
        SwapNetwork.bitcoin => OrderSwapNetwork.bitcoin,
        SwapNetwork.liquid => OrderSwapNetwork.liquid,
        SwapNetwork.lightning => OrderSwapNetwork.lightning,
      };

  SwapNetwork get toSwapNetwork => switch (this) {
    OrderSwapNetwork.bitcoin => SwapNetwork.bitcoin,
    OrderSwapNetwork.liquid => SwapNetwork.liquid,
    OrderSwapNetwork.lightning => SwapNetwork.lightning,
  };
}
