import '../endpoints.dart';

class SameImage {
  final String id;
  final String? blobHash;
  final String? blobPrefix;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final String? source;
  final String? postUrl;
  final String? sourceUrl;
  final String? title;
  final String? description;
  final bool? nsfw;
  final Map<String, dynamic>? tags;
  final double? aspectRatio;

  const SameImage({
    required this.id,
    this.blobHash,
    this.blobPrefix,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.source,
    this.postUrl,
    this.sourceUrl,
    this.title,
    this.description,
    this.nsfw,
    this.tags,
    this.aspectRatio,
  });

  String get displayThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }
    if (blobHash != null && blobHash!.isNotEmpty) {
      if (blobPrefix != null &&
          blobPrefix!.isNotEmpty &&
          blobHash!.length >= 4) {
        final secondThird = blobHash!.substring(0, 2);
        final fourthFifth = blobHash!.substring(2, 4);
        return '${Endpoints.cdnBase}/thumbnails/blobs/$blobPrefix/$secondThird/$fourthFifth/$blobHash';
      }
      return Endpoints.thumbnailUrl(blobHash!);
    }
    // For uploaded images (SHA-1 hash IDs)
    if (id.length == 40) {
      return '${Endpoints.apiBase}${Endpoints.thumbnailById(id)}';
    }
    return '';
  }

  double get displayAspectRatio =>
      aspectRatio ??
      (width != null && height != null && height! > 0 ? width! / height! : 1.0);

  bool get isUploadedImage => id.length == 40;

  factory SameImage.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : null;

    final String id = json['id']?.toString() ?? '';
    final String? hash =
        json['sha1']?.toString() ??
        json['hash']?.toString() ??
        json['blob']?.toString();
    final String? prefix = json['prefix']?.toString();
    String? thumbUrl;

    if (hash != null && hash.isNotEmpty) {
      if (prefix != null && prefix.isNotEmpty && hash.length >= 4) {
        final secondThird = hash.substring(0, 2);
        final fourthFifth = hash.substring(2, 4);
        thumbUrl =
            '${Endpoints.cdnBase}/thumbnails/blobs/$prefix/$secondThird/$fourthFifth/$hash';
      } else {
        thumbUrl = Endpoints.thumbnailUrl(hash);
      }
    } else if (json['thumbnail'] != null) {
      thumbUrl = json['thumbnail'].toString();
    }

    return SameImage(
      id: id,
      blobHash: hash,
      blobPrefix: prefix,
      thumbnailUrl: thumbUrl,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      source: metadata?['source']?.toString() ?? json['source']?.toString(),
      postUrl: metadata?['post_url']?.toString(),
      sourceUrl:
          metadata?['original_url']?.toString() ??
          metadata?['post_url']?.toString() ??
          json['source']?.toString() ??
          json['url']?.toString(),
      title: metadata?['title']?.toString() ?? json['title']?.toString(),
      description:
          metadata?['caption']?.toString() ?? json['description']?.toString(),
      nsfw: metadata?['nsfw'] as bool?,
      tags: metadata?['tags'] is Map<String, dynamic>
          ? metadata!['tags'] as Map<String, dynamic>
          : null,
      aspectRatio: json['aspect_ratio'] != null
          ? (json['aspect_ratio'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (blobHash != null) 'sha1': blobHash,
    if (blobPrefix != null) 'prefix': blobPrefix,
    if (thumbnailUrl != null) 'thumbnail': thumbnailUrl,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (source != null) 'source': source,
    if (postUrl != null) 'post_url': postUrl,
    if (sourceUrl != null) 'original_url': sourceUrl,
    if (title != null) 'title': title,
    if (description != null) 'description': description,
    if (nsfw != null) 'nsfw': nsfw,
    if (tags != null) 'tags': tags,
    if (aspectRatio != null) 'aspect_ratio': aspectRatio,
  };
}
