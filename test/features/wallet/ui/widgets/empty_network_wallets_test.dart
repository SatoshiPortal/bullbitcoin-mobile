import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_network_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/load_network_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/empty_network_wallets.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';

class _Settings extends Mock implements SettingsRepository {}

class _References extends Mock implements WalletSecretReferencesRepository {}

class _Defaults extends Mock implements CreateDefaultWalletsUsecase {}

class _WalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

void main() {
  testWidgets(
    'injected setup cubit is created once, loaded and closed by its view',
    (tester) async {
      final settings = _Settings();
      final references = _References();
      when(settings.fetch).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
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
      var creations = 0;
      final view = EmptyNetworkWallets(
        createSetupCubit: () {
          creations++;
          return cubit;
        },
        onMainnet: () {},
        onImport: () {},
      );
      Widget app() => MaterialApp(
        home: BlocProvider<WalletBloc>.value(value: wallets, child: view),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      expect(creations, 1);
      verify(settings.fetch).called(1);
      verifyZeroInteractions(references);
      expect(cubit.isClosed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(cubit.isClosed, isTrue);
      await wallets.close();
    },
  );
}
