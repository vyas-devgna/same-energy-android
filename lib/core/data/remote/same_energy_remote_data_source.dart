import 'dart:async';

import 'package:dio/dio.dart';

import 'stream_response_parser.dart';

class SameEnergyRemoteDataSource {
  SameEnergyRemoteDataSource(this._dio);

  final Dio _dio;

  static const _maxAttempts = 3;

  Future<ParsedStreamResponse> getStream(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _withRetry(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain),
      ),
    );
    return StreamResponseParser.parse(response.data);
  }

  Future<ParsedStreamResponse> postStream(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final response = await _withRetry(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain, headers: headers),
      ),
    );
    return StreamResponseParser.parse(response.data);
  }

  Future<ParsedStreamResponse> putStream(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    void Function(int, int)? onSendProgress,
  }) async {
    final response = await _withRetry(
      () => _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain, headers: headers),
        onSendProgress: onSendProgress,
      ),
    );
    return StreamResponseParser.parse(response.data);
  }

  Future<String> postRaw(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    final response = await _withRetry(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.plain, headers: headers),
      ),
    );
    final raw = response.data;
    return raw is String ? raw : raw?.toString() ?? '';
  }

  Future<Response<dynamic>> _withRetry(
    Future<Response<dynamic>> Function() request,
  ) async {
    DioException? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await request();
      } on DioException catch (error) {
        lastError = error;
        if (!_shouldRetry(error) || attempt == _maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 200 * attempt * attempt),
        );
      }
    }
    throw lastError!;
  }

  bool _shouldRetry(DioException error) {
    final type = error.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final status = error.response?.statusCode ?? 0;
    return status >= 500 || status == 429;
  }
}
