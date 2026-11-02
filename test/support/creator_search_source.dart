import 'dart:collection';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/res.dart';
import 'comic_source_fixture.dart';

/// No network or author/tag conversion. Records ordinary source queries.
class CreatorSearchSource extends ComicSourceFixture {
  CreatorSearchSource(String sourceKey, {this.displayName = 'Test platform'})
    : super(key: sourceKey);
  final String displayName;
  @override
  String get name => displayName;
  final requests = <(String, int, List<String>)>[];
  @override
  SearchPageData get searchPageData => SearchPageData(
    [
      SearchOptions(
        LinkedHashMap.of({'normal': 'Normal', 'other': 'Other'}),
        'Order',
        'select',
        'normal',
      ),
    ],
    (text, page, options) async {
      requests.add((text, page, List.of(options)));
      return Res([
        Comic(
          'Controlled result $page · $displayName',
          '',
          'result-$page',
          null,
          [],
          '',
          key,
          null,
          null,
        ),
      ], subData: 2);
    },
    null,
  );
}
