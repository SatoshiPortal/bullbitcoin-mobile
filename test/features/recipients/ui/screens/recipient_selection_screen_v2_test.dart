import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

typedef _SelectionHook =
    Future<void>? Function(RecipientViewModel, {required bool isNew});

void main() {
  setUpAll(() => registerFallbackValue(const RecipientsEvent.started()));

  for (final isNew in [false, true]) {
    testWidgets(
      'invalid owner stays on the picker with a typed failure (new: $isNew)',
      (tester) async {
        final bloc = _MockRecipientsBloc();
        whenListen(
          bloc,
          const Stream<RecipientsState>.empty(),
          initialState: RecipientsState(
            allowedRecipientFilters: RecipientFilterCriteria(
              types: [RecipientType.sepaEur],
              isOwner: true,
            ),
            recipients: [],
          ),
        );
        _SelectionHook? hook;
        locator.registerFactoryParam<
          RecipientsBloc,
          RecipientFilterCriteria?,
          _SelectionHook?
        >((filter, callback) {
          expect(filter?.isOwner, isTrue);
          hook = callback;
          return bloc;
        });
        addTearDown(() => locator.unregister<RecipientsBloc>());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RecipientSelectionScreenV2(isConfidential: false),
          ),
        );
        await tester.pumpAndSettle();
        final loc = AppLocalizations.of(
          tester.element(find.byType(RecipientSelectionScreenV2)),
        );
        if (isNew) {
          await tester.tap(find.text(loc.recipientsTabNew));
          await tester.pumpAndSettle();
        }
        final onSelected = hook;
        expect(onSelected, isNotNull);
        if (onSelected == null) return;
        await onSelected(
          const RecipientViewModel(
            id: 'someone-else',
            type: RecipientType.sepaEur,
            isOwner: false,
          ),
          isNew: isNew,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(RecipientSelectionScreenV2), findsOneWidget);
        expect(
          find.text(
            isNew
                ? loc.recipientsErrorSavedButNotSelected
                : loc.oopsSomethingWentWrong,
          ),
          findsOneWidget,
        );
      },
    );
  }
}
