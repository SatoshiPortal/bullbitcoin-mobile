import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:signers/storage.dart';
import 'package:swaps/order_swaps.dart';
import 'package:swaps/swaps.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'domain/delete_wallet_usecase.dart';
import 'domain/discover_wallet_usecase.dart';
import 'domain/read_wallet_details_usecase.dart';
import 'presentation/wallet_details_cubit.dart';
import 'presentation/wallet_discovery_cubit.dart';
import 'ui/wallet_details_screen.dart';

const walletDetailsRouteName = 'walletDetailsSelectedWallet';
const walletDetailsRoutePath = 'wallet-details/:walletId';

/// One wallet's public description, discovery and deletion.
GoRoute walletDetailsRoute({
  required SecretsInventory inventory,
  required SignerDevices devices,
  required WalletNativeLifecycle native,
  required SwapStore swaps,
  required OrderSwaps orders,
  required SeedReferences references,
  required Secrets secrets,
  required Future<Result<void, Failure>> Function(String walletId) discover,
  required void Function(BuildContext context) onDeleted,
}) {
  final read = ReadWalletDetailsUsecase(inventory, devices);
  final delete = DeleteWalletUsecase(
    inventory: inventory,
    native: native,
    swaps: swaps,
    orders: orders,
    references: references,
    secrets: secrets,
  );
  final discovery = DiscoverWalletUsecase(discover);
  return GoRoute(
    name: walletDetailsRouteName,
    path: walletDetailsRoutePath,
    builder: (context, state) {
      final walletId = state.pathParameters['walletId'];
      if (walletId == null) return const SizedBox.shrink();
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                WalletDetailsCubit(read, delete, inventory.lockedChanges)
                  ..load(walletId),
          ),
          BlocProvider(create: (_) => WalletDiscoveryCubit(discovery)),
        ],
        child: WalletDetailsScreen(onDeleted: onDeleted),
      );
    },
  );
}
