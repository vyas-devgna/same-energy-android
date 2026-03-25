import 'dart:convert';
import 'dart:typed_data';

class ParsedStreamResponse {
  final Map<String, dynamic>? successPayload;
  final List<Map<String, dynamic>> frames;
  final String rawText;

  const ParsedStreamResponse({
    required this.successPayload,
    required this.frames,
    required this.rawText,
  });
}

class StreamResponseParser {
  static ParsedStreamResponse parse(dynamic responseData) {
    final raw = _toText(responseData);
    final frames = _extractFrames(raw);

    Map<String, dynamic>? success;
    for (final frame in frames) {
      final kind = frame['kind']?.toString().toLowerCase();
      if (kind == 'success') {
        final payload = frame['payload'];
        if (payload is Map<String, dynamic>) {
          success = payload;
        } else if (payload is List) {
          success = {'images': payload};
        } else if (payload != null) {
          success = {'value': payload};
        } else {
          success = frame;
        }
      }
    }

    if (success == null && frames.length == 1) {
      success = frames.first;
    }

    return ParsedStreamResponse(
      successPayload: success,
      frames: frames,
      rawText: raw,
    );
  }

  static String _toText(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    if (data is Uint8List) return utf8.decode(data);
    if (data is Map || data is List) return jsonEncode(data);
    return data.toString();
  }

  static List<Map<String, dynamic>> _extractFrames(String raw) {
    final frames = <Map<String, dynamic>>[];
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          frames.add(decoded);
        } else if (decoded is List) {
          frames.add({'images': decoded});
        }
      } catch (_) {
        // Ignore non-json chunks in streamed responses.
      }
    }

    if (frames.isEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) frames.add(decoded);
        if (decoded is List) frames.add({'images': decoded});
      } catch (_) {}
    }

    return frames;
  }
}
