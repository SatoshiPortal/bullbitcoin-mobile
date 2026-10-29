import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/resolve_notification_wallet_usecase.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../broadcast_signed_tx/wallet_fixture.dart';

class _Wallets extends Mock implements GetWalletsUsecase {}

void main() {
  test(
    'a notification tap resolves its receiving wallet after decoding',
    () async {
      final get = _Wallets();
      final wallet = publicBroadcastWallet();
      when(() => get.execute()).thenAnswer((_) async => Ok([wallet]));
      final key = WalletNetworkKey(wallet.id, 'bitcoin', 'mainnet');
      final destination = NotificationDestination.wallet(
        WalletPaymentNotificationIdentity.topicId(key),
      );
      final decoded = NotificationsFacade.decodeDestination(
        NotificationsFacade.encodeDestination(destination),
      );
      if (decoded case Ok(
        value: WalletNotificationDestination(:final walletKey),
      )) {
        expect(
          await ResolveNotificationWalletUsecase(get: get).execute(walletKey),
          wallet.id,
        );
      } else {
        fail('Wallet destination must decode');
      }
      expect(
        await ResolveNotificationWalletUsecase(get: get).execute('ab' * 32),
        isNull,
      );
    },
  );
}
