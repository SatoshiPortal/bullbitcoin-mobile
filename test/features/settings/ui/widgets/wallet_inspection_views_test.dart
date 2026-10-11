import 'dart:async';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/dropdown/signer_device_dropdown.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../bullvault/bullvault_test_fixture.dart';

class _Get extends Mock implements GetWalletPolicyUsecase {}

class _Update extends Mock implements UpdateWalletSignerDeviceUsecase {}

void main() {
  late _Get get;
  late _Update update;
  final fixture = testBullVaultCreateResult(walletId: 'selected');
  final key = fixture.record.recoveryPackage.policy.coldKey.accountKey;
  final signer = WalletSigner(
    id: key.signerId,
    signer: .remote,
    signerDevice: null,
    descriptorKeys: [key],
  );
  final wallet = fixture.wallet.copyWith(signers: [signer]);
  final root = BitcoinSignaturePolicyNode(
    id: 'root',
    key: BitcoinPolicyKey(kind: .descriptorKey, value: key.id),
  );
  final policy = BitcoinWalletPolicy(
    external: BitcoinSpendingPolicy(root: root, requiresPath: false),
    internal: BitcoinSpendingPolicy(root: root, requiresPath: false),
  );
  setUp(() {
    get = _Get();
    update = _Update();
    locator.registerFactory<WalletDetailsCubit>(
      () => WalletDetailsCubit(
        getWalletPolicyUsecase: get,
        updateWalletSignerDeviceUsecase: update,
      ),
    );
  });
  tearDown(() => locator.reset());
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  testWidgets('policy read uses the selected id and can retry a failure', (
    tester,
  ) async {
    when(
      () => get.execute('selected'),
    ).thenAnswer((_) async => const Err(SettingsWalletPolicyFailure()));
    await pump(
      tester,
      WalletPolicyView(
        walletId: 'selected',
        builder: (_, value) =>
            Text(identical(value, policy) ? 'loaded' : 'wrong'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().walletDetailsUnavailableLabel),
      findsOneWidget,
    );
    when(() => get.execute('selected')).thenAnswer((_) async => Ok(policy));
    await tester.tap(find.text(AppLocalizationsEn().retry));
    await tester.pumpAndSettle();
    expect(find.text('loaded'), findsOneWidget);
    verify(() => get.execute('selected')).called(2);
  });
  testWidgets(
    'device label saves through the existing owner and only success asks for reload',
    (tester) async {
      var reloads = 0;
      when(
        () => update.execute(
          walletId: 'selected',
          signerId: signer.id,
          signerDevice: SignerDeviceEntity.ledgerNanoX,
        ),
      ).thenAnswer((_) async => Ok(wallet));
      await pump(
        tester,
        WalletKeysView(
          wallet: wallet,
          signerSummaryBuilder: (_, _) => const Text('verified summary'),
          accountKeyBuilder: (_, key) => Text(key.xpub),
          onSignerDeviceUpdated: () => reloads++,
        ),
      );
      expect(find.text('verified summary'), findsOneWidget);
      tester
          .widget<SignerDeviceDropdown>(find.byType(SignerDeviceDropdown))
          .onChanged!(SignerDeviceEntity.ledgerNanoX);
      await tester.pumpAndSettle();
      expect(reloads, 1);
      verify(
        () => update.execute(
          walletId: 'selected',
          signerId: signer.id,
          signerDevice: SignerDeviceEntity.ledgerNanoX,
        ),
      ).called(1);
    },
  );
  testWidgets(
    'a failed device save and starting its retry do not report success',
    (tester) async {
      var reloads = 0;
      const device = SignerDeviceEntity.ledgerNanoX;
      when(
        () => update.execute(
          walletId: 'selected',
          signerId: signer.id,
          signerDevice: device,
        ),
      ).thenAnswer((_) async => Ok(wallet));
      await pump(
        tester,
        WalletKeysView(
          wallet: wallet,
          signerSummaryBuilder: (_, _) => const Text('summary'),
          accountKeyBuilder: (_, key) => Text(key.xpub),
          onSignerDeviceUpdated: () => reloads++,
        ),
      );
      void save() => tester
          .widget<SignerDeviceDropdown>(find.byType(SignerDeviceDropdown))
          .onChanged!(device);
      save();
      await tester.pumpAndSettle();
      expect(reloads, 1);
      when(
        () => update.execute(
          walletId: 'selected',
          signerId: signer.id,
          signerDevice: device,
        ),
      ).thenAnswer((_) async => const Err(SettingsStorageFailure()));
      save();
      await tester.pumpAndSettle();
      expect(reloads, 1);
      final pending = Completer<Result<Wallet, SettingsFailure>>();
      when(
        () => update.execute(
          walletId: 'selected',
          signerId: signer.id,
          signerDevice: device,
        ),
      ).thenAnswer((_) => pending.future);
      save();
      await tester.pump();
      expect(reloads, 1);
      pending.complete(const Err(SettingsStorageFailure()));
      await tester.pumpAndSettle();
    },
  );
}
