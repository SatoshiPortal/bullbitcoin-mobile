import 'package:primitives/primitives.dart' show Ok;
import 'package:preferences/preferences.dart';
import 'package:provisioning/provisioning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/empty_network_wallets.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements Preferences {}

class _References extends Mock implements WalletInventory {}

class _Defaults extends Mock implements DefaultWalletProvisioning {}

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

void main() {
  testWidgets(
    'injected setup cubit is created once, loaded and closed by its view',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => Ok((
          environment: Environment.mainnet,
          isSuperuser: false,
          isDevModeEnabled: false,
        )),
      );
      final cubit = NetworkWalletSetupCubit(
        NetworkWalletProvisioning(
          settings: settings,
          inventory: references,
          defaults: _Defaults(),
        ),
      );
      final wallets = _WalletBloc();
      whenListen(
        wallets,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(),
      );
      var creations = 0;
      final view = EmptyNetworkWallets(
        createSetupCubit: () {
          creations++;
          return cubit;
        },
        onMainnet: () {},
        onImport: () {},
        onRecoverEncryptedVault: () {},
      );
      Widget app() => MaterialApp(
        home: BlocProvider<WalletBloc>.value(value: wallets, child: view),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      expect(creations, 1);
      verify(settings.readDeveloperEnvironment).called(1);
      verifyZeroInteractions(references);
      expect(cubit.isClosed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(cubit.isClosed, isTrue);
      await wallets.close();
    },
  );
}
