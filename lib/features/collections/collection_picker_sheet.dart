import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models/image_model.dart';
import 'collection_lock_sheet.dart';
import 'collections_provider.dart';

class CollectionSaveResult {
  final List<String> selectedCollectionNames;
  final SameImage image;
  final Set<String> previousCollectionIds;
  final Set<String> nextCollectionIds;

  const CollectionSaveResult({
    required this.selectedCollectionNames,
    required this.image,
    required this.previousCollectionIds,
    required this.nextCollectionIds,
  });
}

Future<CollectionSaveResult?> showCollectionPickerSheet(
  BuildContext context, {
  required SameImage image,
}) async {
  return showModalBottomSheet<CollectionSaveResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CollectionPickerSheet(image: image),
  );
}

class _CollectionPickerSheet extends ConsumerStatefulWidget {
  const _CollectionPickerSheet({required this.image});

  final SameImage image;

  @override
  ConsumerState<_CollectionPickerSheet> createState() =>
      _CollectionPickerSheetState();
}

class _CollectionPickerSheetState
    extends ConsumerState<_CollectionPickerSheet> {
  final TextEditingController _newCollectionController =
      TextEditingController();
  late Set<String> _selectedCollectionIds;
  late Set<String> _initialCollectionIds;
  bool _newCollectionPrivate = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(savedItemsProvider.notifier);
    _initialCollectionIds = notifier.collectionIdsForImage(widget.image.id);
    _selectedCollectionIds = Set<String>.from(_initialCollectionIds);
  }

  @override
  void dispose() {
    _newCollectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedState = ref.watch(savedItemsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Save to Collections',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newCollectionController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'New collection name',
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _newCollectionPrivate,
            title: const Text('Make new collection private'),
            subtitle: const Text('Requires a 4-digit PIN to open.'),
            onChanged: (value) {
              setState(() => _newCollectionPrivate = value);
            },
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: savedState.orderedCollections.map((collection) {
                  final selected = _selectedCollectionIds.contains(
                    collection.id,
                  );
                  return CheckboxListTile(
                    key: ValueKey(collection.id),
                    value: selected,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(collection.name),
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedCollectionIds.add(collection.id);
                        } else {
                          _selectedCollectionIds.remove(collection.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final notifier = ref.read(savedItemsProvider.notifier);
                final initialSelected = Set<String>.from(
                  _selectedCollectionIds,
                );
                final newName = _newCollectionController.text.trim();
                if (newName.isNotEmpty && _newCollectionPrivate) {
                  final configured = await ensureCollectionLockPinConfigured(
                    context,
                    ref,
                  );
                  if (!configured) return;
                }
                try {
                  await notifier.saveImageToCollections(
                    widget.image,
                    initialSelected,
                    newCollectionName: newName.isEmpty ? null : newName,
                    newCollectionPrivate: _newCollectionPrivate,
                  );
                } catch (error) {
                  if (!mounted) return;
                  final msg = error is StateError ? error.message : 'Failed to save collection.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg.toString())),
                  );
                  return;
                }

                final nextState = ref.read(savedItemsProvider);
                final nextIds = nextState.collectionIdsForImage(
                  widget.image.id,
                );
                final selectedNames = nextState
                    .collectionIdsForImage(widget.image.id)
                    .map((id) => nextState.collections[id]?.name ?? '')
                    .where((name) => name.isNotEmpty)
                    .toList();

                if (!mounted) return;
                if (!Navigator.of(context).canPop()) return;
                Navigator.of(context).pop(
                  CollectionSaveResult(
                    selectedCollectionNames: selectedNames,
                    image: widget.image,
                    previousCollectionIds: Set<String>.from(
                      _initialCollectionIds,
                    ),
                    nextCollectionIds: Set<String>.from(nextIds),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
