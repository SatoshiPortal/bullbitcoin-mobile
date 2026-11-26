import 'package:primitives/primitives.dart' show Ok;
import 'package:preferences/preferences.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:provisioning/provisioning.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/empty_network_wallets.dart';
import 'package:bb_mobile/localizations.dart';
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
    'regtest setup does not claim Liquid software wallets are unavailable',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.readDeveloperEnvironment).thenAnswer(
        (_) async => Ok((
          environment: Environment.regtest,
          isSuperuser: true,
          isDevModeEnabled: true,
        )),
      );
      final cubit = NetworkWalletSetupCubit(
        LoadNetworkWalletSetupUsecase(settings, references),
        CreateNetworkWalletUsecase(
          settings,
          references,
          Secrets(scratchDirectory: () async => '/tmp'),
          _Defaults(),
        ),
      );
      final wallets = _WalletBloc();
      whenListen(
        wallets,
        const Stream<WalletState>.empty(),
        initialState: const WalletState(),
      );
      await tester.pumpWidget(
        BlocProvider<WalletBloc>.value(
          value: wallets,
          child: MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyNetworkWallets(
                createSetupCubit: () => cubit,
                onMainnet: () {},
                onImport: () {},
                onRecoverEncryptedVault: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Liquid:'), findsNothing);
      expect(find.text('Regtest'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await wallets.close();
    },
  );
}
