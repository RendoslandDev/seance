import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// "12 Jun · 7:08 PM" — no intl dependency.
String _formatDate(DateTime dt) {
  final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '${dt.day} ${_months[dt.month - 1]} · $h12:$min $ampm';
}

// ----------------------------------------------------------------------------
// Composer
// ----------------------------------------------------------------------------

/// Bottom-sheet composer for a new reflection inline. When [sessionTitle] is provided
/// the entry is attached to that session (written from a card's Reflect action).
Future<void> showJournalComposer(
  BuildContext context,
  AppState state, {
  String? sessionTitle,
  int? dayNumber,
}) {
  final controller = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.bg1,
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'New reflection',
                    style: TextStyle(
                      fontFamily: AppType.serif,
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      color: Palette.textHi,
                    ),
                  ),
                ),
                if (sessionTitle != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _ContextPill(sessionTitle: sessionTitle),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: Palette.textHi,
                    fontSize: 15.5,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    hintText: 'What surfaced for you?',
                    hintStyle: TextStyle(color: Palette.textLow, fontSize: 15),
                    filled: true,
                    fillColor: Palette.surface,
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Palette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Palette.borderStrong),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () {
                      state.addJournalEntry(
                        controller.text,
                        sessionTitle: sessionTitle,
                        dayNumber: dayNumber,
                      );
                      Navigator.of(ctx).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.textHi,
                      side: BorderSide(color: Palette.borderStrong),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.sessionTitle});
  final String sessionTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.border),
      ),
      child: Text('ON · ${sessionTitle.toUpperCase()}', style: AppType.badge),
    );
  }
}

// ----------------------------------------------------------------------------
// Journal tab
// ----------------------------------------------------------------------------

class JournalView extends StatelessWidget {
  const JournalView({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.journal;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 38, color: Palette.textLow),
            const SizedBox(height: 22),
            const _Title('Journal'),
            const SizedBox(height: 14),
            Text(
              'Capture a reflection and it will\nbe waiting for you here.',
              textAlign: TextAlign.center,
              style: AppType.cardBody.copyWith(height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => showJournalComposer(context, state),
              icon: const Icon(Icons.add, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.textHi,
                side: BorderSide(color: Palette.borderStrong),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              label: const Text('New reflection'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 8, 24, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 18),
          child: Row(
            children: [
              const _Title('Journal'),
              const Spacer(),
              IconButton(
                onPressed: () => showJournalComposer(context, state),
                icon: Icon(Icons.add, size: 22, color: Palette.textHi),
                tooltip: 'New reflection',
              ),
            ],
          ),
        ),
        for (final e in entries) _JournalEntryCard(entry: e, state: state),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppType.serif,
        fontSize: 34,
        fontWeight: FontWeight.w500,
        color: Palette.textHi,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry, required this.state});

  final JournalEntry entry;
  final AppState state;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.bg1,
        title: Text(
          'Delete reflection?',
          style: TextStyle(fontFamily: AppType.serif, color: Palette.textHi),
        ),
        content: Text('This cannot be undone.', style: AppType.cardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Palette.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: Palette.textHi)),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteJournalEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onLongPress: () => _confirmDelete(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_formatDate(entry.createdAt), style: AppType.badge),
                    const Spacer(),
                    if (entry.linkedToSession)
                      _ContextPill(sessionTitle: entry.sessionTitle!),
                  ],
                ),
                const SizedBox(height: 12),
                Text(entry.body, style: AppType.cardBody),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
