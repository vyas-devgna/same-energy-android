import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  late final Dio _telemetryDio;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Endpoints.apiBase,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _dio.interceptors.add(_HeaderInterceptor());

    _telemetryDio = Dio(
      BaseOptions(
        baseUrl: Endpoints.apiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _telemetryDio.interceptors.add(_HeaderInterceptor());
  }

  Dio get dio => _dio;
  Dio get telemetryDio => _telemetryDio;

  static String generateAcceptTime() {
    final random = Random.secure();
    final bytes = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      bytes[i] = random.nextInt(256);
    }
    // Convert 8 bytes to a large unsigned decimal string
    BigInt value = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      value = (value << 8) | BigInt.from(bytes[i]);
    }
    return value.toUnsigned(64).toString();
  }
}

class _HeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['accept-time'] = ApiClient.generateAcceptTime();
    options.headers['origin'] = Endpoints.webOrigin;
    if (options.method == 'POST') {
      options.headers['content-type'] = 'text/plain;charset=UTF-8';
    }
    handler.next(options);
  }
}
