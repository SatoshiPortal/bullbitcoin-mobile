import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bull_ui/bull_ui.dart' show BullText;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class _Cubit extends Fake implements ImportWatchOnlyCubit {
  @override
  ImportWatchOnlyState get state => const ImportWatchOnlyState();
  @override
  Stream<ImportWatchOnlyState> get stream => const Stream.empty();
}

class _Descriptor extends Fake implements satoshifier.WatchOnlyDescriptor {}

class _Xpub extends Fake implements satoshifier.WatchOnlyXpub {}

void main() {
  for (final descriptor in [true, false]) {
    testWidgets(
      'missing ${descriptor ? 'descriptor' : 'xpub'} selection renders an unavailable message',
      (tester) async {
        final wallet = descriptor
            ? WatchOnlyWalletEntity.descriptor(
                watchOnlyDescriptor: _Descriptor(),
              )
            : WatchOnlyWalletEntity.xpub(watchOnlyXpub: _Xpub());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ImportWatchOnlyCubit>.value(
              value: _Cubit(),
              child: Scaffold(
                body: WatchOnlyDetailsWidget(watchOnlyWallet: wallet),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(WatchOnlyDetailsWidget));
        expect(
          find.text(AppLocalizations.of(context).oopsSomethingWentWrong),
          findsOneWidget,
        );
        expect(find.byType(BullText), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
