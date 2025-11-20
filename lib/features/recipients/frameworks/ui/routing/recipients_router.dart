import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_filters_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecipientsRoute {
  recipients('/recipients');

  final String path;
  const RecipientsRoute(this.path);
}

class RecipientsRouteExtra {
  final AllowedRecipientFiltersViewModel? allowedRecipientsFilters;
  final void Function(RecipientViewModel recipient) onRecipientSelected;

  RecipientsRouteExtra({
    this.allowedRecipientsFilters,
    required this.onRecipientSelected,
  });
}

class RecipientsRouter {
  static final route = GoRoute(
    name: RecipientsRoute.recipients.name,
    path: RecipientsRoute.recipients.path,
    builder: (context, state) {
      // In case the calling code wants to limit the selectable recipient types,
      // we can pass them through the `extra` parameter when navigating to this route.
      final extra = state.extra! as RecipientsRouteExtra;

      return BlocProvider<RecipientsBloc>(
        create:
            (context) =>
                locator<RecipientsBloc>(param1: extra.allowedRecipientsFilters)
                  ..add(const RecipientsEvent.started()),
        child: BlocListener<RecipientsBloc, RecipientsState>(
          listenWhen:
              (previous, current) =>
                  previous.selectedRecipient != current.selectedRecipient &&
                  current.hasSelectedRecipient,
          listener: (context, state) {
            // TODO: Move this callback to the 'onContinue' handler in the BLoC
            // so ze cqn catch errors and show loading indicators.
            // Pass the handler as the second Bloc parameter.
            extra.onRecipientSelected.call(state.selectedRecipient!);
          },
          child: const RecipientsScreen(),
        ),
      );
    },
  );
}
