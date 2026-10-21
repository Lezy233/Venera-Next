import 'dart:async';

import 'package:venera_next/components/select.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/features/reader/reader_mode_labels.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_layout.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/log.dart';

class ReaderModeSettings extends StatefulWidget {
  const ReaderModeSettings({
    super.key,
    this.comicId,
    this.sourceKey,
    this.scope = ReaderPreferenceScope.active,
    this.currentMode,
    this.isDetecting,
    this.onDetect,
    this.onChanged,
  });

  final String? comicId;
  final String? sourceKey;
  final ReaderPreferenceScope scope;
  final String Function()? currentMode;
  final bool Function()? isDetecting;
  final Future<void> Function()? onDetect;
  final VoidCallback? onChanged;

  @override
  State<ReaderModeSettings> createState() => _ReaderModeSettingsState();
}

class _ReaderModeSettingsState extends SettingsSaveState<ReaderModeSettings> {
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  ReaderPreferenceStore get _store => ReaderPreferenceStore(
    settings: appdata.settings,
    scope: widget.scope,
    comicId: widget.comicId,
    sourceKey: widget.sourceKey,
  );

  Future<bool> _setPreference<T extends Object>(
    Preference<T> preference,
    T value,
  ) {
    final target = (widget.comicId, widget.sourceKey);
    return saveSetting(
      preference.key,
      () => appdata.updateSettings((draft) {
        ReaderPreferenceStore(
          settings: draft,
          scope: widget.scope,
          comicId: widget.comicId,
          sourceKey: widget.sourceKey,
        ).write(preference, value);
      }),
      onSaved: () => widget.onChanged?.call(),
      isCurrent: () => target == (widget.comicId, widget.sourceKey),
    );
  }

  Widget _preference(
    String title,
    Preference<String> preference, {
    String? description,
  }) {
    final value = _store.read(preference);
    final keys = readerModeLabels.keys.toList();
    return ListTile(
      title: Text(title.tl),
      subtitle: description == null ? null : Text(description.tl),
      trailing: Select(
        current: readerModeLabels[value] ?? value,
        values: [for (final key in keys) readerModeLabels[key]!],
        minWidth: 96,
        onTap: (index) {
          if (index < 0 || index >= keys.length) return;
          unawaited(_setPreference(preference, keys[index]));
        },
      ),
    );
  }

  String _pageUnitLabel(int value) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode != 'zh') return '$value';
    final traditional =
        locale.scriptCode == 'Hant' || locale.countryCode == 'TW';
    return traditional ? '$value頁' : '$value页';
  }

  Widget _pagesPerScreen({String? cid, String? source}) {
    final scoped = cid != null && source != null;
    final scope = scoped ? ReaderPreferenceScope.comic : widget.scope;
    final store = ReaderPreferenceStore(
      settings: appdata.settings,
      scope: scope,
      comicId: cid,
      sourceKey: source,
    );
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final preference = landscape
        ? ReaderPreferences.readerScreenPicNumberForLandscape
        : ReaderPreferences.readerScreenPicNumberForPortrait;
    final current = store.read(preference).toInt();
    final modified =
        scoped &&
        current !=
            ReaderPreferenceStore(
              settings: appdata.settings,
              scope: ReaderPreferenceScope.global,
            ).read(preference).toInt();
    return _ModifiedRow(
      modified: modified,
      child: ListTile(
        title: Text('Pages per screen'.tl),
        trailing: Select(
          current: _pageUnitLabel(current),
          values: [_pageUnitLabel(1), _pageUnitLabel(2)],
          minWidth: 64,
          onTap: (index) {
            if (index < 0 || index > 1) return;
            if (scoped &&
                (cid != widget.comicId || source != widget.sourceKey)) {
              return;
            }
            final value = index + 1;
            unawaited(
              saveSetting(
                (cid, source, 'pagesPerScreen'),
                () => appdata.updateSettings((draft) {
                  final target = ReaderPreferenceStore(
                    settings: draft,
                    scope: scope,
                    comicId: cid,
                    sourceKey: source,
                  );
                  target.write(
                    ReaderPreferences.readerScreenPicNumberForPortrait,
                    value,
                  );
                  target.write(
                    ReaderPreferences.readerScreenPicNumberForLandscape,
                    value,
                  );
                }),
                onSaved: () => widget.onChanged?.call(),
                isCurrent: () =>
                    !scoped ||
                    (cid == widget.comicId && source == widget.sourceKey),
              ),
            );
          },
        ),
      ),
    );
  }

  ReaderPreferenceScope _thumbnailScope(String? cid, String? source) =>
      cid != null && source != null
      ? ReaderPreferenceScope.comic
      : widget.scope;

  int _pagesPerUnit(String? cid, String? source) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final preference = landscape
        ? ReaderPreferences.readerScreenPicNumberForLandscape
        : ReaderPreferences.readerScreenPicNumberForPortrait;
    return ReaderPreferenceStore(
      settings: appdata.settings,
      scope: _thumbnailScope(cid, source),
      comicId: cid,
      sourceKey: source,
    ).read(preference).toInt();
  }

  Widget _skipFirstPage({String? cid, String? source}) {
    final scoped = cid != null && source != null;
    final scope = _thumbnailScope(cid, source);
    final store = ReaderPreferenceStore(
      settings: appdata.settings,
      scope: scope,
      comicId: cid,
      sourceKey: source,
    );
    final current = store.read(ReaderPreferences.showSingleImageOnFirstPage);
    return ListTile(
      title: Text('Skip first page'.tl),
      trailing: Select(
        current: (current ? 'Yes' : 'No').tl,
        values: ['No'.tl, 'Yes'.tl],
        minWidth: 64,
        onTap: (index) {
          if (index < 0 || index > 1) return;
          if (scoped && (cid != widget.comicId || source != widget.sourceKey)) {
            return;
          }
          final value = index == 1;
          unawaited(
            saveSetting(
              (cid, source, 'skipFirstPage'),
              () => appdata.updateSettings((draft) {
                ReaderPreferenceStore(
                  settings: draft,
                  scope: scope,
                  comicId: cid,
                  sourceKey: source,
                ).write(ReaderPreferences.showSingleImageOnFirstPage, value);
              }),
              onSaved: () => widget.onChanged?.call(),
              isCurrent: () =>
                  !scoped ||
                  (cid == widget.comicId && source == widget.sourceKey),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = appdata.settings;
    final auto = _store.read(ReaderPreferences.autoReaderMode) == true;
    final cid = widget.comicId;
    final source = widget.sourceKey;
    if (cid == null || source == null) {
      final body = Column(
        children: [
          SwitchListTile(
            title: Text('Choose reading mode automatically'.tl),
            subtitle: Text(
              'Recognize paged and long-strip comics from image proportions.'
                  .tl,
            ),
            value: auto,
            onChanged: (value) =>
                _setPreference(ReaderPreferences.autoReaderMode, value),
          ),
          if (auto) ...[
            _preference('Paged comics', ReaderPreferences.pagedReaderMode),
            _preference(
              'Long-strip comics',
              ReaderPreferences.longStripReaderMode,
            ),
          ],
          _preference(
            auto ? 'When layout is unknown' : 'Default reading mode',
            ReaderPreferences.readerMode,
            description: auto
                ? 'Used when there are too few images or their proportions are mixed.'
                : null,
          ),
          _pagesPerScreen(),
          if (_pagesPerUnit(null, null) == 2) _skipFirstPage(),
        ],
      );
      return withSettingsSaveFeedback(body);
    }

    final override = settings.comicReaderModeOverride(cid, source);
    final effective = settings.resolveReaderMode(cid, source);
    final current = widget.currentMode?.call() ?? effective;
    final layout = settings.comicLayout(cid, source);
    final detecting = _detecting || (widget.isDetecting?.call() ?? false);
    final layoutLabel = switch (layout) {
      ComicLayout.paged => 'Paged comic'.tl,
      ComicLayout.longStrip => 'Long-strip comic'.tl,
      ComicLayout.unknown => 'Not identified'.tl,
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModifiedRow(
          modified:
              override != null &&
              override != _store.read(ReaderPreferences.readerMode),
          child: ListTile(
            title: Text('Reading mode for this comic'.tl),
            subtitle: Text(
              'Currently using: @mode'.tlParams({
                'mode': readerModeLabels[current] ?? current,
              }),
            ),
            trailing: Select(
              current: override == null
                  ? 'Follow default'.tl
                  : readerModeLabels[override] ?? override,
              values: [
                'Follow default'.tl,
                for (final key in readerModeLabels.keys) readerModeLabels[key]!,
              ],
              minWidth: 96,
              onTap: (index) {
                final keys = ['default', ...readerModeLabels.keys];
                if (index < 0 || index >= keys.length) return;
                // The menu can outlive a target change; do not write the old
                // comic's setting in that case.
                if (cid != widget.comicId || source != widget.sourceKey) return;
                final value = keys[index];
                unawaited(
                  saveSetting(
                    (cid, source, 'readerMode'),
                    () => appdata.updateSettings((draft) {
                      draft.setComicReaderModeOverride(
                        cid,
                        source,
                        value == 'default' ? null : value,
                      );
                    }),
                    onSaved: () => widget.onChanged?.call(),
                    isCurrent: () =>
                        cid == widget.comicId && source == widget.sourceKey,
                  ),
                );
              },
            ),
          ),
        ),
        _pagesPerScreen(cid: cid, source: source),
        if (_pagesPerUnit(cid, source) == 2)
          _skipFirstPage(cid: cid, source: source),
        if (auto) ...[
          ListTile(
            leading: Icon(switch (layout) {
              ComicLayout.paged => Icons.auto_stories_outlined,
              ComicLayout.longStrip => Icons.view_day_outlined,
              ComicLayout.unknown => Icons.aspect_ratio,
            }),
            title: Text(
              detecting ? 'Identifying comic layout…'.tl : layoutLabel,
            ),
            subtitle: Text(
              (override != null
                      ? 'Your choice for this comic takes priority.'
                      : layout == ComicLayout.unknown
                      ? 'Not enough consistent image proportions to identify the layout.'
                      : 'Recognized from image proportions. Your reading preference applies automatically.')
                  .tl,
            ),
          ),
          if (widget.onDetect != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: detecting
                      ? null
                      : () async {
                          setState(() => _detecting = true);
                          try {
                            await widget.onDetect!();
                          } catch (error, stack) {
                            Log.error('Layout detection', error, stack);
                            if (context.mounted) {
                              context.showMessage(message: error.toString());
                            }
                          } finally {
                            if (mounted) setState(() => _detecting = false);
                          }
                        },
                  child: Text('Identify again from this chapter'.tl),
                ),
              ),
            ),
        ],
      ],
    );
    return withSettingsSaveFeedback(body);
  }
}

class _ModifiedRow extends StatelessWidget {
  const _ModifiedRow({required this.modified, required this.child});

  final bool modified;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: modified
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }
}
