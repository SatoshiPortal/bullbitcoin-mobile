import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'announcements_failure.dart';

typedef Dismissal = ({String id, DateTime dismissedAt});

abstract interface class AnnouncementDismissals {
  @useResult
  Future<Result<List<Dismissal>, AnnouncementsFailure>> read();

  @useResult
  Future<Result<void, AnnouncementsFailure>> dismiss(String id, DateTime at);
}
