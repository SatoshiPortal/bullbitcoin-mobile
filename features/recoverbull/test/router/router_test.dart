import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/ui/screens/vault_selected_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _RecoverBullBloc extends Mock implements RecoverBullBloc {}

void main() {
  testWidgets('View Vault Key replaces settings with its RecoverBull flow', (
    tester,
  ) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/recoverbull-settings-test',
      routes: [
        GoRoute(
          path: '/recoverbull-settings-test',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => openRecoverBullFlow(
                context,
                flow: RecoverBullFlow.viewVaultKey,
              ),
              child: const Text('View Vault Key'),
            ),
          ),
        ),
        GoRoute(
          name: RecoverBullRoute.recoverbullFlows.name,
          path: RecoverBullRoute.recoverbullFlows.path,
          builder: (context, state) {
            final extra = state.extra! as RecoverBullFlowsExtra;
            return Text(extra.flow.name);
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('View Vault Key'));
    await tester.pumpAndSettle();

    expect(find.text(RecoverBullFlow.viewVaultKey.name), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('See more vaults preserves the flow and vault in route extra', (
    tester,
  ) async {
    final vault = EncryptedVault(file: _vaultFixture);
    final bloc = _RecoverBullBloc();
    when(
      () => bloc.state,
    ).thenReturn(const RecoverBullState(flow: RecoverBullFlow.viewVaultKey));
    when(
      () => bloc.stream,
    ).thenAnswer((_) => const Stream<RecoverBullState>.empty());
    final router = GoRouter(
      initialLocation: '/selected',
      routes: [
        GoRoute(
          path: '/selected',
          builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
            value: bloc,
            child: VaultSelectedPage(
              provider: VaultProvider.googleDrive,
              vault: vault,
              flow: RecoverBullFlow.viewVaultKey,
            ),
          ),
        ),
        GoRoute(
          name: RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.name,
          path: RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.path,
          builder: (context, state) {
            final extra = state.extra! as RecoverBullFlowsExtra;
            return Text('${extra.flow.name}:${extra.vault?.id}');
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('See more vaults'));
    await tester.pumpAndSettle();

    expect(
      find.text('${RecoverBullFlow.viewVaultKey.name}:${vault.id}'),
      findsOneWidget,
    );
  });
}

const _vaultFixture =
    '{"created_at":784044000000,"id":"09a6ed8f4de8fd73b73e2392ea78410b7b306d7090cd6f91ed91e7d1c1159799","ciphertext":"U2FiHun3tiRRzVIyJKWwPFmvnfzPJ/K/OzbASAoOIamOP4NRs8ADU7CR87NsxS5mp2dzbl3wgiquhCdQVABJXhHRpTQS7PlCwbbIg2Vj9o3PBoERCfeeD2KRv8uD+6HjNkm33zdHDK/dt1uAYUCcJtqP9ARhn+bUPlKBIW0XP/fIiH94LuU4+AXjN2WD8SBWX1VtS+CrORofA+eMLphLRh2ibzEGotvfrlp52/VjSd5sY3LGkr12lapLSfx4zILhgc2AqgUeFn4Nv8v8F6d3kZ372ikuie963MrncvTS4LxIVO723zX+Lp86bUcDXRtb6B4ZTVHhmRABGqYnviamf84dpcCbC2JhvPHBnOVGTMgf5KbIiBsCNFTKlRmaEnj2HSJLFeC6yBNop02jQ/XkgjFC+35Z7cvO2sKhB5Es0uo=","salt":"658d4287b027f95ae7e5b9f52a5439a4","path":"m/1608\'/0\'/586053381"}';
