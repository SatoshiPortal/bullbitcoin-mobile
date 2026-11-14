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
      '${liquid ? 'Liquid' : 'Bitcoin'} sync follows reveal and pass completion',
      (tester) async {
        final requests = <(String, bool Function())>[];
        final selected = ValueNotifier<(String?, int?)>(('displayed', null));
        final completions = <Completer<void>>[];
        final poll = PollReceiveWalletUsecase(
          WalletFacade(
            const Stream.empty(),
            pollWallet: (id, {required isActive}) async {
              requests.add((id, isActive));
              final completion = Completer<void>();
              completions.add(completion);
              await completion.future;
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
                  walletId: id.$1,
                  isLiquid: liquid,
                  revealGeneration: id.$2,
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
        const delay = Duration(seconds: 20);
        expect(ReceivePolling.receiveResyncDelay, delay);
        await tester.pump(delay * 3);
        expect(requests, isEmpty); // Reveal has not committed.
        selected.value = ('displayed', 1);
        await tester.pump();
        expect(requests.map((r) => r.$1), ['displayed']);
        expect(requests.last.$2(), isTrue);
        await tester.pump(const Duration(seconds: 65));
        expect(requests, hasLength(1)); // Long sync has not ended.
        completions.last.complete();
        await tester.pump();
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(requests, hasLength(1));
        await tester.pump(const Duration(milliseconds: 1));
        expect(requests, hasLength(2));

        // New address: stop the old epoch while persistence is pending.
        selected.value = ('displayed', null);
        await tester.pump();
        expect(requests.last.$2(), isFalse);
        completions.last.complete();
        await tester.pump(delay * 3);
        expect(requests, hasLength(2));
        selected.value = ('displayed', 2);
        await tester.pump();
        expect(requests, hasLength(3));

        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        expect(requests.last.$2(), isFalse);
        completions.last.complete();
        await tester.pump(delay * 3);
        expect(requests, hasLength(3));
        // Resume must still wait if a new address is being prepared.
        selected.value = ('displayed', null);
        await tester.pump();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump(delay * 3);
        expect(requests, hasLength(3));
        selected.value = ('displayed', 3);
        await tester.pump();
        expect(requests, hasLength(4));
        expect(requests.first.$2(), isFalse);

        unawaited(router.push<void>('/other'));
        await tester.pumpAndSettle();
        expect(requests.last.$2(), isFalse);
        completions.last.complete();
        await tester.pump(delay * 3);
        expect(requests, hasLength(4));
        router.pop();
        await tester.pumpAndSettle();
        expect(requests, hasLength(5)); // Retained committed address.

        selected.value = ('next', null);
        await tester.pump();
        expect(requests.last.$2(), isFalse);
        selected.value = ('next', 4);
        await tester.pump();
        expect(requests.last.$1, 'next');
        expect(requests, hasLength(6));
        completions[4].complete(); // Old wallet completion cannot rearm.
        await tester.pump(delay * 3);
        expect(requests, hasLength(6));
        // A pre-admission exception stays quiet and retains completion-based retry.
        completions.last.completeError(Exception('unavailable'));
        await tester.pump();
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(requests, hasLength(6));
        await tester.pump(const Duration(milliseconds: 1));
        expect(requests, hasLength(7));
        await tester.pumpWidget(const SizedBox());
        expect(requests.last.$2(), isFalse);
        completions.last.complete();
        await tester.pump(delay * 2);
        expect(requests, hasLength(7));
        router.dispose();
        selected.dispose();
      },
    );
  }
}
