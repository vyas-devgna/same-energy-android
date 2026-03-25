import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../storage/preferences_storage.dart';
import 'event_models.dart';

class ClickstreamService with WidgetsBindingObserver {
  static final ClickstreamService _instance = ClickstreamService._internal();
  factory ClickstreamService() => _instance;

  final ApiClient _apiClient = ApiClient();
  final List<ClickstreamEvent> _eventBuffer = [];
  Timer? _flushTimer;
  late final String _deviceId;
  late final String _tabId;
  late DateTime _sessionStart;
  String _userId = '';
  String _token = '';

  static const int _maxBatchSize = 20;
  static const Duration _flushInterval = Duration(seconds: 5);

  ClickstreamService._internal();

  void init() {
    _deviceId = PreferencesStorage.getDeviceId();
    _tabId = _generateRandomId(16);
    _sessionStart = DateTime.now();
    _startFlushTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  void updateUser(String userId, String token) {
    _userId = userId;
    _token = token;
  }

  int get _elapsedMs => DateTime.now().difference(_sessionStart).inMilliseconds;

  void trackEvent(Map<String, dynamic> eventData) {
    _eventBuffer.add(ClickstreamEvent(ms: _elapsedMs, data: eventData));
    if (_eventBuffer.length >= _maxBatchSize) {
      _flush();
    }
  }

  void trackOpen(double width, double height, double pixelRatio) {
    trackEvent(
      OpenEvent.create(
        href: 'https://same.energy/',
        userAgent: 'SameEnergy/1.0 (Android; Flutter)',
        platform: 'Android',
        isTouchDevice: true,
        clientWidth: width.toInt(),
        clientHeight: height.toInt(),
        pixelRatio: pixelRatio,
      ),
    );
  }

  void trackHover(
    String route,
    List<String> visible,
    String target,
    String url,
  ) {
    trackEvent(
      HoverEvent.create(
        route: route,
        visible: visible,
        target: target,
        url: url,
      ),
    );
  }

  void trackExpand(
    String route,
    List<String> visible,
    String target,
    String url,
  ) {
    trackEvent(
      ExpandEvent.create(
        route: route,
        visible: visible,
        target: target,
        url: url,
      ),
    );
  }

  void trackSearch(List<String> ids, String text, String index) {
    trackEvent(SearchEvent.create(ids: ids, text: text, index: index));
  }

  void trackSelectFeed(String feed) {
    trackEvent(SelectFeedEvent.create(feed: feed));
  }

  void trackSetRoute(String route) {
    trackEvent(SetRouteEvent.create(route: route));
  }

  void trackModalType(String name) {
    trackEvent(ModalTypeEvent.create(name: name));
  }

  void trackSetKv(String key, dynamic value) {
    trackEvent(SetKvEvent.create(key: key, value: value));
  }

  void trackResetFyp() {
    trackEvent(ResetFypEvent.create());
  }

  void trackLogin(
    String provisionalUserId,
    String provisionalToken,
    String intent,
  ) {
    trackEvent(
      LoginEvent.create(
        provisional: {'user_id': provisionalUserId, 'token': provisionalToken},
        intent: intent,
      ),
    );
  }

  void trackPagehide() {
    trackEvent(PagehideEvent.create());
    _flush();
  }

  void trackPopstate(List<String> visible, String fromUrl, String toUrl) {
    trackEvent(
      PopstateEvent.create(visible: visible, fromUrl: fromUrl, toUrl: toUrl),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      trackPagehide();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStart = DateTime.now();
      _tabId;
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  Future<void> _flush() async {
    if (_eventBuffer.isEmpty) return;
    final events = List<ClickstreamEvent>.from(_eventBuffer);
    _eventBuffer.clear();

    final payload = jsonEncode({
      'kind': 'append',
      'path': 'clickstream.jsonl',
      'data': {
        'device': _deviceId,
        'tab': _tabId,
        'events': events.map((e) => e.toJson()).toList(),
        'ms': _elapsedMs,
      },
      'user_id': _userId.isNotEmpty
          ? _userId
          : PreferencesStorage.getAnonymousUserId(),
      'token': _token,
    });

    try {
      await _apiClient.telemetryDio.post(Endpoints.userData, data: payload);
    } catch (_) {
      // Fire-and-forget: silently ignore errors
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _flush();
  }

  String _generateRandomId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
