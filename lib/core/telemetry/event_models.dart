class ClickstreamEvent {
  final int ms;
  final Map<String, dynamic> data;

  const ClickstreamEvent({required this.ms, required this.data});

  Map<String, dynamic> toJson() => {'ms': ms, 'data': data};
}

class OpenEvent {
  static Map<String, dynamic> create({
    required String href,
    required String userAgent,
    required String platform,
    required bool isTouchDevice,
    required int clientWidth,
    required int clientHeight,
    required double pixelRatio,
  }) => {
    'kind': 'open',
    'href': href,
    'userAgent': userAgent,
    'platform': platform,
    'isTouchDevice': isTouchDevice,
    'clientWidth': clientWidth,
    'clientHeight': clientHeight,
    'pixelRatio': pixelRatio,
  };
}

class HoverEvent {
  static Map<String, dynamic> create({
    required String route,
    required List<String> visible,
    required String target,
    required String url,
  }) => {
    'kind': 'hover',
    'route': route,
    'visible': visible,
    'target': target,
    'url': url,
  };
}

class ExpandEvent {
  static Map<String, dynamic> create({
    required String route,
    required List<String> visible,
    required String target,
    required String url,
  }) => {
    'kind': 'expand',
    'route': route,
    'visible': visible,
    'target': target,
    'url': url,
  };
}

class SearchEvent {
  static Map<String, dynamic> create({
    required List<String> ids,
    required String text,
    required String index,
  }) => {'kind': 'search', 'ids': ids, 'text': text, 'index': index};
}

class SelectFeedEvent {
  static Map<String, dynamic> create({required String feed}) => {
    'kind': 'select_feed',
    'feed': feed,
  };
}

class SetRouteEvent {
  static Map<String, dynamic> create({required String route}) => {
    'kind': 'set_route',
    'route': route,
  };
}

class ModalTypeEvent {
  static Map<String, dynamic> create({required String name}) => {
    'kind': 'modal_type',
    'name': name,
  };
}

class SetKvEvent {
  static Map<String, dynamic> create({
    required String key,
    required dynamic value,
  }) => {'kind': 'set_kv', 'key': key, 'value': value};
}

class ResetFypEvent {
  static Map<String, dynamic> create() => {'kind': 'reset_fyp'};
}

class LoginEvent {
  static Map<String, dynamic> create({
    required Map<String, String> provisional,
    required String intent,
  }) => {'kind': 'login', 'provisional': provisional, 'intent': intent};
}

class PagehideEvent {
  static Map<String, dynamic> create() => {'kind': 'pagehide'};
}

class PopstateEvent {
  static Map<String, dynamic> create({
    required List<String> visible,
    required String fromUrl,
    required String toUrl,
  }) => {
    'kind': 'popstate',
    'visible': visible,
    'fromUrl': fromUrl,
    'toUrl': toUrl,
  };
}
