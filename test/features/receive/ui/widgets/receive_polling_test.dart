import 'dart:async';

import 'package:bb_mobile/features/receive/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:bb_mobile/features/receive/ui/widgets/receive_polling.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final liquid in [false, true]) {
    testWidgets(
      'delayed ${liquid ? 'Liquid' : 'Bitcoin'} polling follows visibility',
      (tester) async {
        final requests = <(String, bool Function())>[];
        final selected = ValueNotifier<String?>('displayed');
        final poll = PollReceiveWalletUsecase(
          WalletFacade(
            const Stream.empty(),
            pollWallet: (id, {required isActive}) async {
              requests.add((id, isActive));
            },
          ),
        );
        final path = '/receive/${liquid ? 'liquid' : 'bitcoin'}';
        final root = GlobalKey<NavigatorState>();
        final router = GoRouter(
          navigatorKey: root,
          initialLocation: path,
          routes: [
            ShellRoute(
              builder: (_, _, child) => ValueListenableBuilder(
                valueListenable: selected,
                builder: (_, id, _) => ReceivePolling(
                  walletId: id,
                  isLiquid: liquid,
                  poll: poll,
                  child: child,
                ),
              ),
              routes: [
                GoRoute(path: path, builder: (_, _) => const SizedBox()),
              ],
            ),
            GoRoute(path: '/other', builder: (_, _) => const SizedBox()),
          ],
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Router.withConfig(config: router),
          ),
        );
        final interval = liquid
            ? const Duration(seconds: 30)
            : const Duration(seconds: 15);
        expect(requests, isEmpty);
        await tester.pump(interval - const Duration(milliseconds: 1));
        expect(requests, isEmpty);
        await tester.pump(const Duration(milliseconds: 1));
        expect(requests.map((r) => r.$1), ['displayed']);
        expect(requests.last.$2(), isTrue);
        await tester.pump(interval);
        expect(requests, hasLength(2));

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        expect(requests.last.$2(), isFalse);
        await tester.pump(interval * 3);
        expect(requests, hasLength(2));
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump(interval - const Duration(milliseconds: 1));
        expect(requests, hasLength(2));
        await tester.pump(const Duration(milliseconds: 1));
        expect(requests, hasLength(3));
        // An old queued request must not revive when the same wallet resumes.
        expect(requests.first.$2(), isFalse);

        unawaited(router.push<void>('/other'));
        await tester.pumpAndSettle();
        expect(requests.last.$2(), isFalse);
        await tester.pump(interval * 3);
        expect(requests, hasLength(3));
        router.pop();
        await tester.pumpAndSettle();
        await tester.pump(interval);
        expect(requests, hasLength(4));

        selected.value = 'next';
        await tester.pump();
        expect(requests.last.$2(), isFalse);
        await tester.pump(interval);
        expect(requests.last.$1, 'next');
        expect(requests, hasLength(5));
        selected.value = null;
        await tester.pump();
        await tester.pump(interval * 2);
        expect(requests, hasLength(5));
        selected.value = 'displayed';
        await tester.pump();
        await tester.pump(interval);
        expect(requests, hasLength(6));
        await tester.pumpWidget(const SizedBox());
        expect(requests.last.$2(), isFalse);
        await tester.pump(interval * 2);
        expect(requests, hasLength(6));
        router.dispose();
        selected.dispose();
      },
    );
  }
}
