import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
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
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements SettingsRepository {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _Defaults extends Mock implements CreateDefaultWalletsUsecase {}

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

void main() {
  testWidgets(
    'regtest setup does not claim Liquid software wallets are unavailable',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.regtest,
          isSuperuser: true,
          isDevModeEnabled: true,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
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
