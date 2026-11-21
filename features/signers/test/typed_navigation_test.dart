import 'package:signers/routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:signers/signers.dart';

void main() {
  const account = SignerAccount(
    masterFingerprint: '12345678',
    derivationPath: "m/84'/1'/0'",
    xpub: 'public account fixture',
    scriptType: ScriptType.bip84,
    device: SignerDeviceEntity.ledgerNanoX,
    network: NetworkEnv.testnet,
  );
  for (final ledger in [true, false]) {
    for (final operation in ['import', 'sign', 'verify']) {
      testWidgets(
        '${ledger ? 'Ledger' : 'BitBox'} $operation keeps its typed request and result',
        (tester) async {
          Object? received;
          Object? returned;
          var completed = false;
          final route = ledger
              ? switch (operation) {
                  'import' => LedgerRoute.importLedger,
                  'sign' => LedgerRoute.ledgerSignTransaction,
                  _ => LedgerRoute.ledgerVerifyAddress,
                }
              : null;
          final bitboxRoute = switch (operation) {
            'import' => BitBoxRoute.importBitBox,
            'sign' => BitBoxRoute.bitboxSignTransaction,
            _ => BitBoxRoute.bitboxVerifyAddress,
          };
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      switch (operation) {
                        case 'import':
                          final SignerAccount? result = ledger
                              ? await SignersNavigation.importLedger(
                                  context,
                                  network: NetworkEnv.testnet,
                                )
                              : await SignersNavigation.importBitBox(
                                  context,
                                  network: NetworkEnv.testnet,
                                );
                          returned = result;
                        case 'sign':
                          final String? result = ledger
                              ? await SignersNavigation.signLedger(
                                  context,
                                  network: NetworkEnv.testnet,
                                  psbt: 'unsigned',
                                  derivationPath: account.derivationPath,
                                  scriptType: ScriptType.bip84,
                                )
                              : await SignersNavigation.signBitBox(
                                  context,
                                  network: NetworkEnv.testnet,
                                  psbt: 'unsigned',
                                  derivationPath: account.derivationPath,
                                  scriptType: ScriptType.bip84,
                                );
                          returned = result;
                        case 'verify':
                          if (ledger) {
                            await SignersNavigation.verifyLedger(
                              context,
                              network: NetworkEnv.testnet,
                              address: 'address',
                              derivationPath: account.derivationPath,
                              scriptType: ScriptType.bip84,
                            );
                          } else {
                            await SignersNavigation.verifyBitBox(
                              context,
                              network: NetworkEnv.testnet,
                              address: 'address',
                              derivationPath: account.derivationPath,
                              scriptType: ScriptType.bip84,
                            );
                          }
                      }
                      completed = true;
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
              GoRoute(
                path: route?.path ?? bitboxRoute.path,
                name: route?.name ?? bitboxRoute.name,
                builder: (context, state) {
                  received = state.extra;
                  return Scaffold(
                    body: TextButton(
                      onPressed: () {
                        switch (operation) {
                          case 'import':
                            context.pop(account);
                          case 'sign':
                            context.pop('signed');
                          case 'verify':
                            context.pop();
                        }
                      },
                      child: const Text('Return'),
                    ),
                  );
                },
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final (network, psbt, address, path, script) = switch (received) {
            LedgerRouteParams p => (
              p.network,
              p.psbt,
              p.address,
              p.derivationPath,
              p.scriptType,
            ),
            BitBoxRouteParams p => (
              p.network,
              p.psbt,
              p.address,
              p.derivationPath,
              p.scriptType,
            ),
            _ => throw StateError('Missing signer route request'),
          };
          expect(network, NetworkEnv.testnet);
          expect(psbt, operation == 'sign' ? 'unsigned' : null);
          expect(address, operation == 'verify' ? 'address' : null);
          expect(path, operation == 'import' ? null : account.derivationPath);
          expect(script, operation == 'import' ? null : ScriptType.bip84);
          await tester.tap(find.text('Return'));
          await tester.pumpAndSettle();
          expect(completed, isTrue);
          expect(returned, switch (operation) {
            'import' => account,
            'sign' => 'signed',
            _ => null,
          });
        },
      );
    }
  }
}
