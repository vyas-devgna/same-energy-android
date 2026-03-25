class Bookmark {
  final String kind;
  final String id;
  final String? collection;
  final bool removed;
  final DateTime? createdAt;

  const Bookmark({
    this.kind = 'bookmark',
    required this.id,
    this.collection,
    this.removed = false,
    this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      kind: json['kind']?.toString() ?? 'bookmark',
      id: json['id']?.toString() ?? '',
      collection: json['collection']?.toString(),
      removed: json['removed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    if (collection != null) 'collection': collection,
    if (removed) 'removed': true,
  };
}

class BookmarkCollection {
  final String name;
  final List<Bookmark> bookmarks;

  const BookmarkCollection({required this.name, this.bookmarks = const []});
}
