import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'address_view.dart';
import 'src/domain/resolve_address_wallet_usecase.dart';
import 'src/domain/watch_address_revisions_usecase.dart';
import 'src/presentation/address_view_bloc.dart';
import 'src/ui/address_view_route.dart';
import 'src/ui/addresses_screen.dart';

export 'generated/l10n/address_view_localizations.dart'
    show AddressViewLocalizations;

final class AddressViewFeature {
  final AddressView addresses;
  final GoRoute route;

  const AddressViewFeature._(this.addresses, this.route);

  factory AddressViewFeature.mount({
    required Labels labels,
    required WalletInventory inventory,
    required WalletNativeLifecycle native,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required Stream<WalletRevisionState> revisions,
  }) {
    final addresses = AddressView.open(
      labels: labels,
      inventory: inventory,
      native: native,
      loadWallet: loadWallet,
    );
    final watchRevisions = WatchAddressRevisionsUsecase(
      ResolveAddressWalletUsecase(inventory),
      revisions,
    );
    return AddressViewFeature._(
      addresses,
      GoRoute(
        path: AddressViewRoute.path,
        name: AddressViewRoute.name,
        builder: (context, state) {
          final walletId = state.pathParameters['walletId'] ?? '';
          return BlocProvider(
            create: (_) => AddressViewBloc(
              addresses: addresses,
              watchRevisions: watchRevisions,
              walletId: walletId,
              limit: 10,
            ),
            child: AddressesScreen(walletId: walletId),
          );
        },
      ),
    );
  }
}
