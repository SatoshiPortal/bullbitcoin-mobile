import 'package:share_plus/share_plus.dart';

abstract interface class ShareLogsDatasource {
  Future<void> share(List<String> lines);
}

class SharePlusLogsDatasource implements ShareLogsDatasource {
  const SharePlusLogsDatasource();

  @override
  Future<void> share(List<String> lines) => SharePlus.instance.share(
    ShareParams(
      text: lines.join('\n'),
      subject: 'bull_logs.tsv',
      title: 'bull_logs.tsv',
    ),
  );
}
