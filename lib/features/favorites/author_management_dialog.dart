import 'package:flutter/material.dart';
import 'package:venera_next/components/input_dialog.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';

import 'favorite_filters.dart';
import 'favorite_models.dart';

/// Lists every author found in the local favorites and lets the user merge
/// spellings of the same author into one canonical name.
Future<void> showFavoriteAuthorManagementDialog({
  required BuildContext context,
  required List<FavoriteItem> comics,
  required Map<String, String> aliases,
  required bool Function() isCurrent,
  required ValueChanged<Map<String, String>> onChanged,
}) async {
  if (!isCurrent()) return;
  final authors = <String>{};
  for (final comic in comics) {
    authors.addAll(favoriteAuthorValues(comic));
  }
  if (authors.isEmpty) {
    context.showMessage(message: 'No authors found'.tl);
    return;
  }
  final sorted = authors.toList()..sort();
  await showDialog<void>(
    context: context,
    builder: (_) => _AuthorManagementDialog(
      authors: sorted,
      aliases: aliases,
      isCurrent: isCurrent,
      onChanged: onChanged,
    ),
  );
}

class _AuthorManagementDialog extends StatefulWidget {
  const _AuthorManagementDialog({
    required this.authors,
    required this.aliases,
    required this.isCurrent,
    required this.onChanged,
  });

  final List<String> authors;
  final Map<String, String> aliases;
  final bool Function() isCurrent;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  State<_AuthorManagementDialog> createState() =>
      _AuthorManagementDialogState();
}

class _AuthorManagementDialogState extends State<_AuthorManagementDialog> {
  late final localAliases = Map<String, String>.of(widget.aliases);
  final selected = <String>{};
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<String> get _visibleAuthors {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return widget.authors;
    return widget.authors.where((raw) {
      final canonical = localAliases[raw] ?? raw;
      return raw.toLowerCase().contains(keyword) ||
          canonical.toLowerCase().contains(keyword);
    }).toList();
  }

  String _displayName(String raw) => localAliases[raw] ?? raw;

  void _publish() {
    widget.onChanged(Map<String, String>.unmodifiable(localAliases));
  }

  Future<void> _merge() async {
    if (selected.isEmpty || !widget.isCurrent()) return;
    final first = selected.first;
    final targets = Set<String>.of(selected);
    await showInputDialog(
      context: context,
      title: 'Merge authors'.tl,
      hintText: 'Author name'.tl,
      initialValue: _displayName(first),
      confirmText: 'Merge',
      onConfirm: (value) {
        final target = value.trim();
        if (target.isEmpty) {
          throw 'Author name cannot be empty'.tl;
        }
        for (final raw in targets) {
          if (raw == target) {
            localAliases.remove(raw);
          } else {
            localAliases[raw] = target;
          }
        }
        // Aliases that pointed at a merged name follow the new target.
        for (final entry in localAliases.entries.toList()) {
          final next = entry.value;
          if (targets.contains(next) && next != target) {
            localAliases[entry.key] = target;
          }
        }
        setState(selected.clear);
        _publish();
        return null;
      },
    );
  }

  void _reset() {
    if (!widget.isCurrent()) return;
    final targets = selected
        .where((raw) => localAliases[raw] != null)
        .toList(growable: false);
    if (targets.isEmpty) return;
    setState(() {
      for (final raw in targets) {
        localAliases.remove(raw);
      }
      selected.removeAll(targets);
    });
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleAuthors;
    return ContentDialog(
      title: 'Manage authors'.tl,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search'.tl,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No matching authors'.tl),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final raw = visible[index];
                    final canonical = _displayName(raw);
                    return CheckboxListTile(
                      dense: true,
                      value: selected.contains(raw),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(raw);
                          } else {
                            selected.remove(raw);
                          }
                        });
                      },
                      title: Text(canonical),
                      subtitle: canonical == raw ? null : Text(raw),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: selected.isEmpty ? null : _reset,
          child: Text('Reset alias'.tl),
        ),
        FilledButton(
          onPressed: selected.isEmpty ? null : _merge,
          child: Text('Merge'.tl),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text('Close'.tl),
        ),
      ],
    );
  }
}
