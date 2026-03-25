class FeedCategory {
  final String name;
  final List<String> imageIds;

  const FeedCategory({required this.name, this.imageIds = const []});

  factory FeedCategory.fromJson(Map<String, dynamic> json) {
    return FeedCategory(
      name: json['name']?.toString() ?? json['feed']?.toString() ?? '',
      imageIds:
          (json['ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
