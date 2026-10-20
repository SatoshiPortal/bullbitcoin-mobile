import 'exchange_notification_matrix_test.dart' as matrix;
import 'exchange_notifications_test.dart' as basic;

// Standalone Android entrypoint; the root integration aggregator is separate.
Future<void> main() async {
  await basic.main();
  await matrix.main();
}
