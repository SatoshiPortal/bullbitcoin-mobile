import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';

/// A never-closing broadcast stream that models the real SP adapter's
/// notification stream, which only completes when the live session is
/// disposed. A plain `Stream.empty()` completes immediately on listen, which
/// would trip `SpCubit`'s session self-heal (`onDone` -> reload) and loop.
Stream<SpNotification> openSpNotificationStream() =>
    StreamController<SpNotification>.broadcast().stream;
