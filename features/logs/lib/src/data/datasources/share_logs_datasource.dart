import 'package:bull_logger/bull_logger.dart';

abstract interface class ShareLogsDatasource {
  Future<void> share(List<String> lines);
}

class SharePlusLogsDatasource implements ShareLogsDatasource {
  const SharePlusLogsDatasource();

  @override
  Future<void> share(List<String> lines) => shareLogsAsText(lines);
}
