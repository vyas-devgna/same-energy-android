import 'package:flutter_test/flutter_test.dart';

import 'package:same_energy_android_client/core/api/models/image_model.dart';
import 'package:same_energy_android_client/features/search/search_provider.dart';

void main() {
  SameImage image(String id) => SameImage(id: id, thumbnailUrl: 'https://x/$id.jpg');

  test('mergeSearchResultsIntersectionFirst keeps intersection first', () {
    final first = <SameImage>[
      image('a'),
      image('b'),
      image('c'),
      image('d'),
    ];
    final second = <SameImage>[
      image('x'),
      image('b'),
      image('y'),
      image('d'),
      image('z'),
    ];

    final merged = mergeSearchResultsIntersectionFirst(first, second, limit: 20);
    final ids = merged.map((e) => e.id).toList();

    expect(ids, <String>['b', 'd', 'a', 'c', 'x', 'y', 'z']);
  });

  test('mergeSearchResultsIntersectionFirst respects limit', () {
    final first = <SameImage>[image('a'), image('b'), image('c')];
    final second = <SameImage>[image('b'), image('c'), image('d')];
    final merged = mergeSearchResultsIntersectionFirst(first, second, limit: 3);

    expect(merged.map((e) => e.id).toList(), <String>['b', 'c', 'a']);
  });
}
