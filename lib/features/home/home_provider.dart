import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models/feed_model.dart';
import '../../core/api/models/image_model.dart';
import '../../core/auth/auth_state.dart';
import '../../core/data/repositories/same_energy_repository_impl.dart';

class HomeViewState {
  final List<FeedCategory> feeds;
  final List<SameImage> images;
  final String? selectedFeed;
  final bool fromCache;

  const HomeViewState({
    required this.feeds,
    required this.images,
    required this.selectedFeed,
    required this.fromCache,
  });

  HomeViewState copyWith({
    List<FeedCategory>? feeds,
    List<SameImage>? images,
    String? selectedFeed,
    bool? fromCache,
  }) {
    return HomeViewState(
      feeds: feeds ?? this.feeds,
      images: images ?? this.images,
      selectedFeed: selectedFeed ?? this.selectedFeed,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeViewState>(HomeController.new);

class HomeController extends AsyncNotifier<HomeViewState> {
  @override
  Future<HomeViewState> build() async {
    return _loadHomepage();
  }

  Future<HomeViewState> _loadHomepage() async {
    final user = ref.read(authStateProvider);
    final repository = ref.read(sameEnergyRepositoryProvider);
    final home = await repository.fetchHomepage(user: user);
    final feeds = _normalizedFeeds(home.feeds);
    return HomeViewState(
      feeds: feeds,
      images: home.images,
      selectedFeed: null,
      fromCache: home.fromCache,
    );
  }

  List<FeedCategory> _normalizedFeeds(List<FeedCategory> input) {
    final map = <String, FeedCategory>{};
    for (final feed in input) {
      final name = feed.name.trim();
      if (name.isEmpty) continue;
      map[name.toLowerCase()] = FeedCategory(
        name: name,
        imageIds: feed.imageIds,
      );
    }
    return map.values.toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadHomepage);
  }

  Future<void> selectFeed(String? feedName) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (feedName == null || feedName.isEmpty) {
      final refreshed = await _loadHomepage();
      state = AsyncValue.data(refreshed);
      return;
    }

    state = AsyncValue.data(current.copyWith(selectedFeed: feedName));
    final repository = ref.read(sameEnergyRepositoryProvider);
    final images = await repository.fetchFeed(feedName);
    state = AsyncValue.data(
      current.copyWith(
        selectedFeed: feedName,
        images: images,
        fromCache: false,
      ),
    );
  }
}
