import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'src/domain/coins_failure.dart';
import 'src/domain/wallet_utxo.dart';
import 'src/ui/coins_router.dart';

export 'src/domain/coins_failure.dart';
export 'src/domain/wallet_utxo.dart';
export 'src/coin_selection_sheet.dart'
    show CoinSelectionEntry, CoinSelectionLabels, CoinSelectionSheet;
export 'src/ui/widgets/coins_entry.dart' show CoinsEntry;
export 'src/ui/widgets/coins_entry_subtitle.dart' show CoinsEntrySubtitle;
export 'src/ui/widgets/wallet_coin_selection.dart' show walletCoinSelection;

typedef CoinSummary = ({int count, BigInt frozenSat});

abstract interface class Coins {
  @useResult
  Future<Result<List<WalletUtxo>, CoinsFailure>> load({
    required String walletId,
  });

  @useResult
  Future<Result<CoinSummary, CoinsFailure>> summary(String walletId);

  /// A fresh, global read: outpoint exclusion does not depend on attribution.
  @useResult
  Future<Result<List<Outpoint>, CoinsFailure>> frozenOutpoints();
}

abstract final class CoinsNavigation {
  static Future<void> open<T extends Object>(BuildContext context, T wallet) =>
      context.pushNamed<void>(coinsRouteName, extra: wallet);

  static void replace<T extends Object>(BuildContext context, T wallet) =>
      context.pushReplacementNamed(coinsRouteName, extra: wallet);
}
