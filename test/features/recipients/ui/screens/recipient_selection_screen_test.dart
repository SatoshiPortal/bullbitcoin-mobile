import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipients_list_tab.dart';
import 'package:bb_mobile/features/recipients/domain/entities/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/jurisdiction_dropdown.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/recipient_type_selector.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

typedef _SelectionHook = Future<void>? Function(
  RecipientViewModel, {
  required bool isNew,
});

const _ownSepa = RecipientViewModel(
  id: 'own-sepa',
  type: RecipientType.sepaEur,
  isOwner: true,
  firstname: 'Satoshi',
  lastname: 'Nakamoto',
  iban: 'FR7616958000016918327146718',
);

void main() {
  setUpAll(() => registerFallbackValue(const RecipientsEvent.started()));

  for (final invalid in [
    _ownSepa.copyWith(id: 'other-owner', isOwner: false),
    _ownSepa.copyWith(id: 'unknown-owner', isOwner: null),
    _ownSepa.copyWith(id: 'wrong-type', type: RecipientType.interacEmailCad),
  ]) {
    for (final isNew in [false, true]) {
      testWidgets(
        '${invalid.id} stays on the picker with a typed failure (new: $isNew)',
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
              home: const RecipientSelectionScreen.returning(
                types: [RecipientType.sepaEur],
                isOwner: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final loc = AppLocalizations.of(
            tester.element(find.byType(RecipientSelectionScreen)),
          );
          if (isNew) {
            await tester.tap(find.text(loc.recipientsTabNew));
            await tester.pumpAndSettle();
          }
          final onSelected = hook;
          expect(onSelected, isNotNull);
          if (onSelected == null) return;
          await onSelected(invalid, isNew: isNew);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(RecipientSelectionScreen), findsOneWidget);
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

  for (final type in [
    RecipientType.sepaEur,
    RecipientType.confidentialSepaEur,
  ]) {
    testWidgets('the fixed $type method opens its shared form directly', (
      tester,
    ) async {
      final bloc = _MockRecipientsBloc();
      whenListen(
        bloc,
        const Stream<RecipientsState>.empty(),
        initialState: RecipientsState(
          allowedRecipientFilters: RecipientFilterCriteria(
            types: [type],
            isOwner: true,
          ),
          confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
          failedToLoadConfidentialSepaAvailability:
              type == RecipientType.sepaEur
              ? const RecipientsNetworkFailure()
              : null,
          accountOwnerName: const AccountOwnerName(
            firstName: 'Satoshi',
            lastName: 'Nakamoto',
          ),
          recipients: [],
        ),
      );
      locator.registerFactoryParam<
        RecipientsBloc,
        RecipientFilterCriteria?,
        _SelectionHook?
      >((filter, callback) => bloc);
      addTearDown(() => locator.unregister<RecipientsBloc>());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecipientSelectionScreen.returning(
            types: [type],
            isOwner: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final loc = AppLocalizations.of(
        tester.element(find.byType(RecipientSelectionScreen)),
      );
      expect(
        tester
            .widget<RecipientsListTab>(find.byType(RecipientsListTab))
            .enforceRecipientFilter,
        isTrue,
      );
      expect(find.byType(JurisdictionsDropdown), findsNothing);
      await tester.tap(find.text(loc.recipientsTabNew));
      await tester.pumpAndSettle();
      expect(find.byType(RecipientTypeSelector), findsNothing);
      expect(find.byType(JurisdictionsDropdown), findsNothing);
      expect(
        tester.widget<SepaEurForm>(find.byType(SepaEurForm)).isConfidential,
        type == RecipientType.confidentialSepaEur,
      );
      if (type == RecipientType.confidentialSepaEur) {
        expect(find.text('Satoshi Nakamoto'), findsOneWidget);
        expect(find.text(loc.recipientsFieldCorporateAccount), findsNothing);
      } else {
        expect(find.text(loc.recipientsFieldFirstName), findsOneWidget);
        expect(
          find.text(loc.recipientsAccountOwnerSomeoneElse),
          findsOneWidget,
        );
      }
    });
  }

  for (final cancel in [false, true]) {
    testWidgets(
      'returning selection guards late callbacks after ${cancel ? 'cancel' : 'success'}',
      (tester) async {
        final bloc = _MockRecipientsBloc();
        final type = RecipientType.confidentialSepaEur;
        final recipient = _ownSepa.copyWith(
          type: type,
          isVirtualPayeeActive: true,
        );
        whenListen(
          bloc,
          const Stream<RecipientsState>.empty(),
          initialState: RecipientsState(
            allowedRecipientFilters: RecipientFilterCriteria(
              types: [type],
              isOwner: true,
            ),
            confidentialSepaAvailability: ConfidentialSepaAvailability.ready,
            recipients: [recipient],
          ),
        );
        _SelectionHook? hook;
        locator.registerFactoryParam<
          RecipientsBloc,
          RecipientFilterCriteria?,
          _SelectionHook?
        >((filter, callback) {
          expect(filter?.types, [type]);
          expect(filter?.isOwner, isTrue);
          hook = callback;
          return bloc;
        });
        addTearDown(() => locator.unregister<RecipientsBloc>());
        RecipientSelection? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context)
                        .push<RecipientSelection>(
                          MaterialPageRoute(
                            builder: (_) => RecipientSelectionScreen.returning(
                              types: [type],
                              isOwner: true,
                            ),
                          ),
                        );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final onSelected = hook;
        expect(onSelected, isNotNull);
        if (onSelected == null) return;
        expect(
          tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack,
          isNotNull,
        );
        if (cancel) {
          await tester.tap(find.byIcon(Icons.arrow_back));
        } else {
          await onSelected(recipient, isNew: false);
        }
        await onSelected(recipient, isNew: true);
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
        expect(find.byType(RecipientSelectionScreen), findsNothing);
        expect(tester.takeException(), isNull);
        if (cancel) {
          expect(result, isNull);
        } else {
          expect(result?.id, recipient.id);
          expect(result?.iban, recipient.iban);
          expect(result?.type, type);
          expect(result?.displayName, 'Satoshi Nakamoto');
          expect(result?.isVirtualPayeeActive, isTrue);
        }
      },
    );
  }

  testWidgets(
    'the callback picker keeps its filters, fields, and new-recipient flag',
    (tester) async {
      final bloc = _MockRecipientsBloc();
      final filters = RecipientFilterCriteria(
        types: [RecipientType.interacEmailCad],
        isOwner: true,
      );
      whenListen(
        bloc,
        const Stream<RecipientsState>.empty(),
        initialState: RecipientsState(
          allowedRecipientFilters: filters,
          recipients: [],
        ),
      );
      _SelectionHook? hook;
      locator.registerFactoryParam<
        RecipientsBloc,
        RecipientFilterCriteria?,
        _SelectionHook?
      >((filter, callback) {
        expect(filter?.types, filters.types);
        expect(filter?.isOwner, isTrue);
        hook = callback;
        return bloc;
      });
      addTearDown(() => locator.unregister<RecipientsBloc>());
      final selections = <(RecipientSelection, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecipientSelectionScreen(
            types: filters.types,
            isOwner: true,
            onRecipientSelected: (selection, {required isNew}) async {
              selections.add((selection, isNew));
            },
            onRecipientSelectedHookError: 'Caller selection failed',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<BullTopBar>(find.byType(BullTopBar)).onBack, isNull);
      expect(
        tester
            .widget<RecipientsListTab>(find.byType(RecipientsListTab))
            .enforceRecipientFilter,
        isFalse,
      );
      expect(find.byType(JurisdictionsDropdown), findsOneWidget);
      expect(find.text('Caller selection failed'), findsOneWidget);
      final onSelected = hook;
      expect(onSelected, isNotNull);
      if (onSelected == null) return;
      const recipient = RecipientViewModel(
        id: 'interac',
        type: RecipientType.interacEmailCad,
        isOwner: true,
        email: 'satoshi@example.com',
        securityQuestion: 'Existing question',
        securityAnswer: 'Existing answer',
      );
      await onSelected(recipient, isNew: true);
      await onSelected(recipient, isNew: false);
      expect(selections.map((entry) => entry.$2), [true, false]);
      for (final (selection, _) in selections) {
        expect(selection.id, recipient.id);
        expect(selection.email, recipient.email);
        expect(selection.securityQuestion, recipient.securityQuestion);
        expect(selection.securityAnswer, recipient.securityAnswer);
      }
      expect(find.byType(RecipientSelectionScreen), findsOneWidget);
    },
  );
}
