import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/wallet_details_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullIcon;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockWalletDetailsCubit extends Mock implements WalletDetailsCubit {}

Wallet _wallet({required bool isDefault, List<WalletSigner>? signers}) =>
    Wallet(
      origin: 'wallet-id',
      label: 'Savings',
      network: Network.bitcoinMainnet,
      isDefault: isDefault,
      signers:
          signers ??
          [
            WalletSigner.single(
              masterFingerprint: 'abcd1234',
              xpubFingerprint: 'abcd1234',
              xpub: 'xpub-test',
              derivationPath: "m/84'/0'/0'",
              descriptorPath: '/<0;1>/*',
              signer: SignerEntity.local,
              signerDevice: null,
            ),
          ],
      scriptType: ScriptType.bip84,
      publicDescriptor: 'wpkh([abcd1234/84h/0h/0h]xpub-test/<0;1>/*)',
      balanceSat: BigInt.zero,
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool isDefault,
  Wallet? wallet,
  WalletDeletionGuard? deletionGuard,
}) async {
  final walletBloc = _MockWalletBloc();
  final state = WalletState(
    status: WalletStatus.success,
    wallets: [wallet ?? _wallet(isDefault: isDefault)],
  );
  when(() => walletBloc.state).thenReturn(state);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  final walletDetailsCubit = _MockWalletDetailsCubit();
  when(() => walletDetailsCubit.state).thenReturn(const WalletDetailsState());
  when(() => walletDetailsCubit.stream).thenAnswer((_) => const Stream.empty());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<WalletDetailsCubit>.value(value: walletDetailsCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WalletDetailsScreen(
          walletId: 'wallet-id',
          deletionGuard: deletionGuard,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows and copies wallet information', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await _pumpScreen(tester, isDefault: false);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('abcd1234'), findsOneWidget);
    expect(find.text('xpub-test'), findsOneWidget);
    expect(find.text('Addresses'), findsOneWidget);

    for (final value in [
      'xpub-test',
      _wallet(isDefault: false).publicDescriptor,
    ]) {
      final field = find.ancestor(
        of: find.text(value),
        matching: find.byType(CopyInput),
      );
      final copyButton = find.descendant(
        of: field,
        matching: find.byIcon(Icons.copy_sharp),
      );
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      expect(copied, value);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('shows a repeated account xpub once', (tester) async {
    final signer = WalletSigner(
      id: 'signer-0',
      signer: SignerEntity.local,
      signerDevice: null,
      descriptorKeys: [
        WalletDescriptorKey(
          id: 'key-0',
          signerId: 'signer-0',
          masterFingerprint: 'abcd1234',
          xpubFingerprint: 'abcd1234',
          xpub: 'xpub-test',
          derivationPath: "m/48'/0'/0'/2'",
          descriptorPath: '/<0;1>/*',
        ),
        WalletDescriptorKey(
          id: 'key-1',
          signerId: 'signer-0',
          masterFingerprint: 'abcd1234',
          xpubFingerprint: 'abcd1234',
          xpub: 'xpub-test',
          derivationPath: "m/48'/0'/0'/2'",
          descriptorPath: '/<2;3>/*',
        ),
      ],
    );

    await _pumpScreen(
      tester,
      isDefault: false,
      wallet: _wallet(
        isDefault: false,
        signers: [signer],
      ).copyWith(scriptType: null),
    );

    expect(find.text('xpub-test'), findsOneWidget);
  });

  testWidgets('only offers wallet deletion for a non-default wallet', (
    tester,
  ) async {
    await _pumpScreen(tester, isDefault: true);
    expect(find.byType(BullIcon), findsNothing);

    await _pumpScreen(tester, isDefault: false);
    expect(find.byType(BullIcon), findsOneWidget);
  });

  testWidgets('blocks deletion when a feature owns the wallet lifecycle', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      isDefault: false,
      deletionGuard: (_) async => false,
    );

    await tester.tap(find.byType(BullIcon));
    await tester.pumpAndSettle();

    expect(find.text('This wallet cannot be deleted here.'), findsOneWidget);
    expect(find.text('Delete wallet?'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
