import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:same_energy_android_client/core/api/models/image_model.dart';
import 'package:same_energy_android_client/core/storage/preferences_storage.dart';
import 'package:same_energy_android_client/features/collections/collections_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return null;
            case 'write':
            case 'delete':
            case 'deleteAll':
              return null;
            case 'containsKey':
              return false;
            case 'readAll':
              return <String, String>{};
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesStorage.init();
  });

  test('creates collection and saves image into it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(savedItemsProvider.notifier);
    final image = SameImage(
      id: 'img_1',
      thumbnailUrl: 'https://example.com/a.jpg',
    );

    final collectionId = await notifier.createCollection('Moodboard');
    await notifier.saveImageToCollections(image, {collectionId});

    final state = container.read(savedItemsProvider);
    expect(state.collections.containsKey(collectionId), isTrue);
    expect(state.images.containsKey('img_1'), isTrue);
    expect(state.images['img_1']!.collectionIds.contains(collectionId), isTrue);
    expect(state.collections[collectionId]!.imageIds.contains('img_1'), isTrue);
  });

  test('deleting collection removes orphaned image completely', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(savedItemsProvider.notifier);
    final image = SameImage(
      id: 'img_2',
      thumbnailUrl: 'https://example.com/b.jpg',
    );

    final collectionId = await notifier.createCollection('ToDelete');
    await notifier.saveImageToCollections(image, {collectionId});
    await notifier.deleteCollection(collectionId);

    final state = container.read(savedItemsProvider);
    expect(state.collections.containsKey(collectionId), isFalse);
    expect(state.images.containsKey('img_2'), isFalse);
    expect(
      state.collections[uncategorizedCollectionId]!.imageIds.contains('img_2'),
      isFalse,
    );
  });

  test('empty save selection removes an existing saved image', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(savedItemsProvider.notifier);
    final image = SameImage(
      id: 'img_3',
      thumbnailUrl: 'https://example.com/c.jpg',
    );

    await notifier.saveImageToCollections(image, {uncategorizedCollectionId});
    await notifier.saveImageToCollections(image, const <String>{});

    final state = container.read(savedItemsProvider);
    expect(state.images.containsKey('img_3'), isFalse);
  });
}
