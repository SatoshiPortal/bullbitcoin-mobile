import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

final _wallet = Wallet(
  origin: 'wallet-1',
  network: Network.bitcoinTestnet,
  xpubFingerprint: 'fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(100000),
);

void main() {
  Future<Rect> continueRect(WidgetTester tester, TransferState state) async {
    final bloc = _MockTransferBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TransferBloc>.value(
          value: bloc,
          child: const SwapPage(),
        ),
      ),
    );
    await tester.pump();

    return tester.getRect(find.text('Continue'));
  }

  testWidgets('Continue stays pinned at the bottom whatever is toggled', (
    tester,
  ) async {
    final internal = await continueRect(
      tester,
      TransferState(fromWallet: _wallet),
    );
    final external = await continueRect(
      tester,
      TransferState(fromWallet: _wallet, sendToExternal: true),
    );
    final consolidating = await continueRect(
      tester,
      TransferState(fromWallet: _wallet, consolidationRequired: true),
    );

    expect(external, internal);
    expect(consolidating, internal);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(internal.bottom, greaterThan(screenHeight - 100));
  });
}
