import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/screens/recipients_screen.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum RecipientsRoute {
  recipients('/recipients');

  final String path;
  const RecipientsRoute(this.path);
}

class RecipientsRouter {
  static final route = GoRoute(
    name: RecipientsRoute.recipients.name,
    path: RecipientsRoute.recipients.path,
    builder: (context, state) {
      // In case the calling code wants to limit the selectable recipient types,
      // we can pass them through the `extra` parameter when navigating to this route.
      final extra = state.extra as Map<String, dynamic>?;
      final selectableRecipientTypes =
          extra?['selectableRecipientTypes'] as Set<RecipientType>?;
      final onRecipientSelected =
          extra?['onRecipientSelected'] as void Function(String recipientId)?;

      return BlocProvider<RecipientsBloc>(
        create:
            (context) =>
                locator<RecipientsBloc>()..add(
                  RecipientsEvent.loaded(
                    selectableRecipientTypes: selectableRecipientTypes,
                  ),
                ),
        child: BlocListener<RecipientsBloc, RecipientsState>(
          listenWhen:
              (previous, current) =>
                  previous.selectedRecipientId != current.selectedRecipientId &&
                  current.hasSelectedRecipient,
          listener: (context, state) {
            onRecipientSelected?.call(state.selectedRecipientId);
          },
          child: const RecipientsScreen(),
        ),
      );
    },
  );
}
