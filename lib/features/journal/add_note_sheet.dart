import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/enums.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/journal_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/photo_store.dart';

/// 新增 / 編輯札記 bottom sheet：文字 + 相片，可綁定到某天（§5.5）。
Future<void> showAddNoteSheet(
  BuildContext context,
  WidgetRef ref,
  String tripId, {
  int? defaultDayIndex,
  JournalEntryRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddNoteForm(
        tripId: tripId,
        defaultDayIndex: defaultDayIndex,
        existing: existing,
      ),
    ),
  );
}

class _AddNoteForm extends ConsumerStatefulWidget {
  const _AddNoteForm({
    required this.tripId,
    this.defaultDayIndex,
    this.existing,
  });
  final String tripId;
  final int? defaultDayIndex;
  final JournalEntryRow? existing;

  @override
  ConsumerState<_AddNoteForm> createState() => _AddNoteFormState();
}

class _AddNoteFormState extends ConsumerState<_AddNoteForm> {
  late final TextEditingController _text =
      TextEditingController(text: widget.existing?.entryText ?? '');
  late final List<String> _photos = <String>[
    ...?widget.existing?.photoPaths,
  ];
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final List<XFile> picked = await _picker.pickMultiImage();
    if (picked.isEmpty) return;
    const PhotoStore store = PhotoStore();
    for (final XFile x in picked) {
      final String path = await store.save(x.path);
      _photos.add(path);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty && _photos.isEmpty) return;
    setState(() => _saving = true);
    final JournalRepository repo = ref.read(journalRepositoryProvider);
    final JournalEntryRow? existing = widget.existing;
    if (existing != null) {
      await repo.updateEntry(
        existing.copyWith(
          entryText: Value<String?>(_text.text.trim()),
          photoPaths: _photos,
          entryType: _photos.isEmpty ? EntryType.note : EntryType.photo,
        ),
      );
    } else {
      await repo.addNote(
        widget.tripId,
        text: _text.text.trim(),
        photoPaths: _photos,
        dayIndex: widget.defaultDayIndex,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.addNote, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: l10n.journalTabNotes,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_photos.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_photos[i]),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _addPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(l10n.addPhoto),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
