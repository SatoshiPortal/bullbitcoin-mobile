import 'package:bb_mobile/network_banner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required NetworkEnv network,
    required bool beta,
    required bool debug,
    Key? key,
  }) => tester.pumpWidget(
    AppliedNetworkBuilder(
      key: key,
      selected: network,
      builder: (context, applied) => MaterialApp(
        debugShowCheckedModeBanner:
            debug &&
            applied != NetworkEnv.testnet &&
            applied != NetworkEnv.regtest,
        builder: (context, child) => networkBanner(
          context: context,
          network: applied,
          beta: beta,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('Wallet')),
      ),
    ),
  );

  List<String> messages(WidgetTester tester) => tester
      .widgetList<Banner>(find.byType(Banner))
      .map((b) => b.message)
      .toList();

  for (final network in [NetworkEnv.testnet, NetworkEnv.regtest]) {
    testWidgets('$network replaces beta and debug banners', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, network: network, beta: true, debug: true);
      expect(messages(tester), [network.name.toUpperCase()]);
      expect(find.bySemanticsLabel(network.name.toUpperCase()), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('mainnet retains both existing banners', (tester) async {
    await pumpApp(tester, network: NetworkEnv.mainnet, beta: true, debug: true);
    expect(messages(tester), containsAll(['BETA', 'DEBUG']));
    expect(messages(tester), hasLength(2));
  });

  testWidgets('mainnet production has no banner', (tester) async {
    await pumpApp(
      tester,
      network: NetworkEnv.mainnet,
      beta: false,
      debug: false,
    );
    expect(messages(tester), isEmpty);
  });

  testWidgets('regtest transition retains applied network until restart', (
    tester,
  ) async {
    await pumpApp(tester, network: NetworkEnv.testnet, beta: true, debug: true);
    await pumpApp(tester, network: NetworkEnv.regtest, beta: true, debug: true);
    expect(messages(tester), ['TESTNET']);
    await pumpApp(
      tester,
      key: UniqueKey(),
      network: NetworkEnv.regtest,
      beta: true,
      debug: true,
    );
    expect(messages(tester), ['REGTEST']);
    await pumpApp(tester, network: NetworkEnv.regtest, beta: true, debug: true);
  });

  testWidgets('leaving regtest keeps its banner until restart', (tester) async {
    await pumpApp(tester, network: NetworkEnv.regtest, beta: true, debug: true);
    await pumpApp(tester, network: NetworkEnv.mainnet, beta: true, debug: true);
    expect(messages(tester), ['REGTEST']);
    await pumpApp(
      tester,
      key: UniqueKey(),
      network: NetworkEnv.mainnet,
      beta: true,
      debug: true,
    );
    expect(messages(tester), containsAll(['BETA', 'DEBUG']));
  });

  testWidgets('mainnet and testnet switch without restart', (tester) async {
    await pumpApp(tester, network: NetworkEnv.mainnet, beta: true, debug: true);
    await pumpApp(tester, network: NetworkEnv.testnet, beta: true, debug: true);
    expect(messages(tester), ['TESTNET']);
    await pumpApp(tester, network: NetworkEnv.mainnet, beta: true, debug: true);
    expect(messages(tester), containsAll(['BETA', 'DEBUG']));
  });
}
