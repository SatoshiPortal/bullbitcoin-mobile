import 'dart:async';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/dropdown/signer_device_dropdown.dart';
import 'package:bb_mobile/core/widgets/settings_entry_item.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/bullvault/ui/bullvault_settings_screen.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';

class _Vaults extends Mock implements BullVaultRepository {}

class _Wallets extends Mock implements GetWalletUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Seeds extends Mock implements SeedVerificationPort {}

class _Details extends Mock implements WalletDetailsCubit {}

void main() {
  final created = testBullVaultCreateResult(
    walletId: '01234567-vault',
    includesInheritance: true,
  );
  final vaults = _Vaults(), wallets = _Wallets(), settings = _Settings();
  final inspect = InspectBullVaultUsecase(vaults, wallets, settings, _Seeds());
  setUp(() {
    when(() => vaults.getAll()).thenAnswer((_) async => Ok([created.record]));
    when(
      () => vaults.getByWalletId(created.wallet.id),
    ).thenAnswer((_) async => Ok(created.record));
    when(
      () => wallets.execute(created.wallet.id),
    ).thenAnswer((_) async => created.wallet);
    when(settings.execute).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
  });

  testWidgets(
    'existing vault cards precede creation and group signer access under BullVault',
    (tester) async {
      final cubit = BullVaultSettingsCubit(inspect);
      addTearDown(cubit.close);
      await cubit.load();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const BullVaultSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/selected/:walletId',
            name: BullVaultFacade.settingsRouteName,
            builder: (_, state) => Scaffold(
              body: Text('Selected ${state.pathParameters['walletId']}'),
            ),
          ),
          GoRoute(
            path: '/signer',
            name: SettingsRoute.signingKeyExport.name,
            builder: (_, _) =>
                const Scaffold(body: Text('Existing signer flow')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      final card = find.textContaining('01234567');
      expect(card, findsOneWidget);
      final policy = created.record.recoveryPackage.policy;
      final createdYear = policy.createdAt!.toLocal().year;
      final recoveryYear = DateTime.fromMillisecondsSinceEpoch(
        policy.recoveryActivationTimestamp! * 1000,
        isUtc: true,
      ).toLocal().year;
      expect(find.textContaining('Created:'), findsOneWidget);
      expect(
        tester.widget<Text>(find.textContaining('Created:')).data,
        contains(createdYear.toString()),
      );
      expect(
        tester.widget<Text>(find.textContaining('First recovery:')).data,
        contains(recoveryYear.toString()),
      );
      expect(find.textContaining('Balance'), findsNothing);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(
          tester
              .getTopLeft(find.text(AppLocalizationsEn().bullVaultCreateEntry))
              .dy,
        ),
      );
      expect(find.text('Use BULL as signer'), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Selected 01234567-vault'), findsOneWidget);
    },
  );

  testWidgets(
    'selected vault owns actions; policy and key inspection stay separate',
    (tester) async {
      final cubit = BullVaultSettingsCubit(inspect);
      addTearDown(cubit.close);
      await cubit.load(created.wallet.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: BullVaultSettingsScreen(
              walletId: created.wallet.id,
              page: BullVaultSettingsPage.selected,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View policy'), findsOneWidget);
      expect(find.text('View keys'), findsOneWidget);
      expect(find.text('Backup & recovery'), findsOneWidget);
      expect(find.text('Import cosigner key'), findsOneWidget);
      expect(find.text('Register vault on another device'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Use external signer'), findsNothing);
    },
  );

  testWidgets('the card names its identifier rather than showing bare hex', (
    tester,
  ) async {
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(_app(cubit, const BullVaultSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Vault ID: 01234567'), findsOneWidget);
    expect(find.text('BullVault · 01234567'), findsNothing);
    expect(find.textContaining('01234567'), findsOneWidget);
  });

  testWidgets('a chosen vault shows its own card and no second selector', (
    tester,
  ) async {
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load(created.wallet.id);
    await tester.pumpWidget(
      _app(
        cubit,
        BullVaultSettingsScreen(
          walletId: created.wallet.id,
          page: BullVaultSettingsPage.selected,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vault ID: 01234567'), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byType(InkWell).first).onTap,
      isNull,
      reason: 'The card is the chosen vault, not another selector',
    );
    expect(find.text(AppLocalizationsEn().bullVaultCreateEntry), findsNothing);
    expect(find.text(AppLocalizationsEn().bullVaultRestoreEntry), findsNothing);
  });

  testWidgets('the policy page carries the policy and no actions', (
    tester,
  ) async {
    _registerWalletDetailsCubit(tester);
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load(created.wallet.id);
    await tester.pumpWidget(
      _app(
        cubit,
        BullVaultSettingsScreen(
          walletId: created.wallet.id,
          page: BullVaultSettingsPage.policy,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WalletPolicyView), findsOneWidget);
    expect(find.byType(SettingsEntryItem), findsNothing);
    expect(find.text('Import cosigner key'), findsNothing);
    expect(find.text(AppLocalizationsEn().psbtSigningTitle), findsNothing);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('the keys page states availability and carries no actions', (
    tester,
  ) async {
    final policy = created.record.recoveryPackage.policy;
    final everyday = policy.everydayKey.accountKey;
    final cold = policy.coldKey.accountKey;
    final inheritance = policy.inheritanceKey!.accountKey;
    final seeds = _Seeds();
    when(
      () => seeds.matchesXpubs(
        fingerprint: any(named: 'fingerprint'),
        keys: any(named: 'keys'),
      ),
    ).thenAnswer((_) async => true);
    when(() => wallets.execute(created.wallet.id)).thenAnswer(
      (_) async => created.wallet.copyWith(
        signers: [
          WalletSigner(
            id: everyday.signerId,
            signer: SignerEntity.local,
            signerDevice: null,
            localSeedFingerprint: 'aaaaaaaa',
            descriptorKeys: [everyday],
          ),
          WalletSigner(
            id: cold.signerId,
            signer: SignerEntity.local,
            signerDevice: null,
            localSeedFingerprint: 'bbbbbbbb',
            descriptorKeys: [cold.copyWith(requiresPassphrase: true)],
          ),
          WalletSigner(
            id: inheritance.signerId,
            signer: SignerEntity.remote,
            signerDevice: null,
            descriptorKeys: [inheritance],
          ),
        ],
      ),
    );
    final cubit = BullVaultSettingsCubit(
      InspectBullVaultUsecase(vaults, wallets, settings, seeds),
    );
    addTearDown(cubit.close);
    _registerWalletDetailsCubit(tester);
    await cubit.load(created.wallet.id);
    await tester.pumpWidget(
      _app(
        cubit,
        BullVaultSettingsScreen(
          walletId: created.wallet.id,
          page: BullVaultSettingsPage.keys,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On this device'), findsOneWidget);
    expect(
      find.text('Passphrase required — not currently verified'),
      findsOneWidget,
    );
    expect(find.text('External key'), findsOneWidget);
    // Only the external signer may be given a device label.
    expect(find.byType(SignerDeviceDropdown), findsOneWidget);
    expect(find.byType(SettingsEntryItem), findsNothing);
    expect(find.text('Import cosigner key'), findsNothing);
  });

  testWidgets('a saved device label makes the keys page recheck availability', (
    tester,
  ) async {
    final details = StreamController<WalletDetailsState>.broadcast();
    addTearDown(details.close);
    _registerWalletDetailsCubit(tester, states: details.stream);
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load(created.wallet.id);
    await tester.pumpWidget(
      _app(
        cubit,
        BullVaultSettingsScreen(
          walletId: created.wallet.id,
          page: BullVaultSettingsPage.keys,
        ),
      ),
    );
    await tester.pumpAndSettle();
    clearInteractions(vaults);

    details.add(WalletDetailsState(updatedWallet: created.wallet));
    await tester.pumpAndSettle();

    verify(() => vaults.getByWalletId(created.wallet.id)).called(1);
  });

  testWidgets('an unknown creation date stays unknown on the card', (
    tester,
  ) async {
    final policy = created.record.recoveryPackage.policy;
    final undated = BullVaultRecord(
      walletId: created.record.walletId,
      lineageId: created.record.lineageId,
      vaultGeneration: created.record.vaultGeneration,
      mobileAccount: created.record.mobileAccount,
      birthHeight: created.record.birthHeight,
      recoveryPackage: BullVaultRecoveryPackage(
        previousVaultId: null,
        policy: _withoutCreationDate(policy),
      ),
      status: created.record.status,
      createdAt: created.record.createdAt,
    );
    when(() => vaults.getAll()).thenAnswer((_) async => Ok([undated]));
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(_app(cubit, const BullVaultSettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Created: Unavailable'), findsOneWidget);
    // The first recovery is an encoded timestamp, so it keeps its real date,
    // and the birth height never becomes one.
    final recoveryYear = DateTime.fromMillisecondsSinceEpoch(
      policy.recoveryActivationTimestamp! * 1000,
      isUtc: true,
    ).toLocal().year;
    expect(
      tester.widget<Text>(find.textContaining('First recovery:')).data,
      contains('$recoveryYear'),
    );
    expect(find.textContaining('${created.record.birthHeight}'), findsNothing);
  });

  testWidgets('the practice entry starts creation on the practice timeline', (
    tester,
  ) async {
    final cubit = BullVaultSettingsCubit(inspect);
    addTearDown(cubit.close);
    await cubit.load();
    String? createdUri;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BullVaultSettingsScreen(),
          ),
        ),
        GoRoute(
          path: '/create',
          name: BullVaultFacade.createRouteName,
          builder: (_, state) {
            createdUri = state.uri.toString();
            return const Scaffold(body: Text('Creation'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.text(AppLocalizationsEn().bullVaultCreatePracticeEntry);
    expect(entry, findsOneWidget);
    // Secondary: it sits below the three primary entries.
    expect(
      tester.getTopLeft(entry).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.text(AppLocalizationsEn().bullVaultUseBullAsSigner),
            )
            .dy,
      ),
    );
    expect(
      find.text(AppLocalizationsEn().bullVaultPracticeTimelineDescription),
      findsOneWidget,
    );
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(createdUri, contains('practice=true'));
  });
}

void _registerWalletDetailsCubit(
  WidgetTester tester, {
  Stream<WalletDetailsState>? states,
}) {
  final cubit = _Details();
  when(() => cubit.state).thenReturn(const WalletDetailsState());
  when(
    () => cubit.stream,
  ).thenAnswer((_) => states ?? const Stream<WalletDetailsState>.empty());
  when(cubit.close).thenAnswer((_) async {});
  when(() => cubit.loadPolicy(any())).thenAnswer((_) async {});
  GetIt.I.registerFactory<WalletDetailsCubit>(() => cubit);
  addTearDown(GetIt.I.reset);
}

/// A vault recovered from its descriptor alone: the encoded activation
/// timestamps survive, the creation date and the original schedule do not.
BullVaultPolicy _withoutCreationDate(BullVaultPolicy policy) => BullVaultPolicy(
  id: policy.id,
  lineageId: policy.lineageId,
  vaultGeneration: policy.vaultGeneration,
  network: policy.network,
  descriptor: policy.descriptor,
  protection: policy.protection,
  everydayKey: policy.everydayKey,
  delayedMobileRecoveryKey: policy.delayedMobileRecoveryKey,
  coldKey: policy.coldKey,
  secondColdKey: policy.secondColdKey,
  inheritanceKey: policy.inheritanceKey,
  schedule: null,
  birthHeight: policy.birthHeight,
  referenceTimestamp: null,
  chainMedianTimePast: null,
  coldActivationTimestamp: policy.coldActivationTimestamp,
  recoveryActivationTimestamp: policy.recoveryActivationTimestamp,
  inheritanceActivationTimestamp: policy.inheritanceActivationTimestamp,
  lastResortActivationTimestamp: policy.lastResortActivationTimestamp,
  createdAt: null,
);

Widget _app(BullVaultSettingsCubit cubit, Widget child) => MaterialApp(
  theme: AppTheme.themeData(AppThemeType.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider.value(value: cubit, child: child),
);
