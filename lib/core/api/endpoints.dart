class Endpoints {
  Endpoints._();

  static const String apiBase = 'https://imageapi.same.energy';
  static const String cdnBase = 'https://blobcdn.same.energy';
  static const String webOrigin = 'https://same.energy';

  // API endpoints
  static const String homepage = '/homepage';
  static const String search = '/search';
  static const String imageInfo = '/image_info';
  static const String userData = '/user_data';
  static const String feed = '/feed';
  static const String thumbnail = '/thumbnail';
  static const String upload = '/upload';
  static const String login = '/login';
  static const String createUser = '/create_user';
  static const String feedback = '/feedback';

  // CDN paths
  static String thumbnailUrl(String blobHash) {
    if (blobHash.length < 5) return '';
    final first = blobHash[0];
    final secondThird = blobHash.substring(0, 2);
    final fourthFifth = blobHash.substring(2, 4);
    return '$cdnBase/thumbnails/blobs/$first/$secondThird/$fourthFifth/$blobHash';
  }

  // Search URL builders
  static String searchByImage(
    String imageId, {
    int n = 100,
    int nsfw = 1,
    String? text,
    bool includeNsfw = true,
  }) {
    final params = <String, String>{'i': imageId, 'n': n.toString()};
    if (includeNsfw) {
      params['nsfw'] = nsfw.toString();
    }
    if (text != null && text.isNotEmpty) {
      params['text'] = text;
    }
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$search?$queryString';
  }

  static String searchByText(String text, {int n = 100}) {
    return '$search?text=${Uri.encodeComponent(text)}&n=$n';
  }

  static String imageInfoUrl(String imageId) {
    return '$imageInfo?i=$imageId';
  }

  static String feedUrl(String feedId) {
    return '$feed?id=${Uri.encodeComponent(feedId)}';
  }

  static String thumbnailById(String id) {
    return '$thumbnail?id=$id';
  }

  static String uploadUrl(int length) {
    return '$upload?length=$length';
  }
}
