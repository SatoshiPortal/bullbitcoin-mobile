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
  final Future<void>? Function(RecipientViewModel recipient)
  onRecipientSelected;

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
            (context) => locator<RecipientsBloc>(
              param1: extra.allowedRecipientsFilters,
              param2: extra.onRecipientSelected,
            )..add(const RecipientsEvent.started()),
        child: const RecipientsScreen(),
      );
    },
  );
}
