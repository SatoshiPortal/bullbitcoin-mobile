import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/public/recoverbull_bindings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

class _WalletBloc extends Mock implements WalletBloc {}

void main() {
  testWidgets(
    'recovery reloads the mounted wallet, not a new factory instance',
    (tester) async {
      final mounted = _WalletBloc();
      when(
        () => mounted.stream,
      ).thenAnswer((_) => const Stream<WalletState>.empty());
      final unused = _WalletBloc();
      final locator = GetIt.instance;
      locator.registerFactory<WalletBloc>(() => unused);
      addTearDown(() => locator.unregister<WalletBloc>());
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<WalletBloc>.value(
            value: mounted,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => WalletRecoverBullBindings.recovered(context),
                child: const Text('Complete'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Complete'));
      verify(() => mounted.add(const WalletStarted())).called(1);
      verifyNever(() => unused.add(const WalletStarted()));
    },
  );
}
