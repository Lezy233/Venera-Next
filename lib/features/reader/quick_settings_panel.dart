import 'dart:async';

import 'package:flutter/material.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/translations.dart';

import 'brightness.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/features/settings/reader_presets.dart';
import 'reader_mode_labels.dart';

enum ReaderQuickSetting {
  mode,
  preset,
  brightness,
  direction,
  zoom,
  animation,
  thumbnails,
}

/// The only list defining the reading panel's high-frequency controls.
const readerQuickSettings = <ReaderQuickSetting>[
  ReaderQuickSetting.mode,
  ReaderQuickSetting.preset,
  ReaderQuickSetting.brightness,
  ReaderQuickSetting.direction,
  ReaderQuickSetting.zoom,
  ReaderQuickSetting.animation,
  ReaderQuickSetting.thumbnails,
];

class ReaderQuickSettingsPanel extends StatefulWidget {
  const ReaderQuickSettingsPanel({
    super.key,
    required this.comicId,
    required this.sourceKey,
    required this.brightnessPreview,
    required this.isCurrent,
    required this.onChanged,
    required this.onAllSettings,
  });

  final String comicId, sourceKey;
  final ReaderBrightnessPreview brightnessPreview;
  final bool Function() isCurrent;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onAllSettings;

  @override
  State<ReaderQuickSettingsPanel> createState() =>
      _ReaderQuickSettingsPanelState();
}

class _ReaderQuickSettingsPanelState
    extends SettingsSaveState<ReaderQuickSettingsPanel> {
  ReaderPreferenceStore get _store => ReaderPreferenceStore(
    settings: appdata.settings,
    scope: ReaderPreferenceScope.comic,
    comicId: widget.comicId,
    sourceKey: widget.sourceKey,
  );

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
    widget.brightnessPreview.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ReaderQuickSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.brightnessPreview, widget.brightnessPreview)) {
      oldWidget.brightnessPreview.removeListener(_refresh);
      widget.brightnessPreview.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _save<T>(
    Preference<T> preference,
    T value, {
    bool enableBrightness = false,
    VoidCallback? releasePreview,
  }) async {
    final comic = widget.comicId, source = widget.sourceKey;
    final current = widget.isCurrent, changed = widget.onChanged;
    if (!acceptsSettingsChanges || !current()) {
      releasePreview?.call();
      return;
    }
    final normalized = preference.normalize(value);
    try {
      await saveSetting(
        (comic, source, preference.key),
        () => appdata.updateSettings((draft) {
          final store = ReaderPreferenceStore(
            settings: draft,
            scope: ReaderPreferenceScope.comic,
            comicId: comic,
            sourceKey: source,
          );
          if (identical(preference, ReaderPreferences.readerMode)) {
            // Full settings uses this same dedicated override, independent of
            // the other comic settings switch and automatic layout detection.
            store.writeComicModeOverride(normalized as String);
          } else {
            store.write(preference, normalized);
          }
          if (enableBrightness) {
            store.write(ReaderPreferences.readerBrightnessEnabled, true);
          }
        }),
        onSaved: () => changed(preference.key),
        isCurrent: () =>
            mounted &&
            comic == widget.comicId &&
            source == widget.sourceKey &&
            current(),
      );
    } finally {
      releasePreview?.call();
    }
  }

  void _brightness(int value) {
    final preview = widget.brightnessPreview;
    final releaseEnabled = preview.previewEnabled(true);
    final releaseValue = preview.previewBrightness(value);
    unawaited(
      _save<num>(
        ReaderPreferences.readerBrightness,
        value,
        enableBrightness: true,
        releasePreview: () {
          releaseEnabled();
          releaseValue();
        },
      ),
    );
  }

  Future<void> _allSettings() async {
    if (!acceptsSettingsChanges || !widget.isCurrent()) return;
    try {
      await waitForSettingsSave();
      if (mounted && widget.isCurrent()) await widget.onAllSettings();
    } catch (error) {
      if (mounted) context.showMessage(message: error.toString());
    }
  }

  Widget _toggle(String title, Preference<bool> preference) => SwitchListTile(
    title: Text(title.tl),
    value: _store.read(preference),
    onChanged: (value) => unawaited(_save(preference, value)),
  );

  Widget _item(ReaderQuickSetting item) => switch (item) {
    ReaderQuickSetting.mode => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_store.read(ReaderPreferences.readerMode)),
        initialValue: _store.read(ReaderPreferences.readerMode),
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Reading Mode'.tl),
        items: [
          for (final entry in readerModeLabels.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            unawaited(_save(ReaderPreferences.readerMode, value));
          }
        },
      ),
    ),
    ReaderQuickSetting.preset => ReaderPresetSelector(
      store: ReaderPresetStore(
        scope: ReaderPreferenceScope.comic,
        comicId: widget.comicId,
        sourceKey: widget.sourceKey,
      ),
      isCurrent: widget.isCurrent,
      onChanged: widget.onChanged,
    ),
    ReaderQuickSetting.brightness => Column(
      children: [
        SwitchListTile(
          title: Text('Reader brightness'.tl),
          value:
              widget.brightnessPreview.enabled ??
              _store.read(ReaderPreferences.readerBrightnessEnabled),
          onChanged: (value) => unawaited(
            _save(
              ReaderPreferences.readerBrightnessEnabled,
              value,
              releasePreview: widget.brightnessPreview.previewEnabled(value),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  semanticFormatterCallback: (value) => '${value.round()}%',
                  label: 'Reader brightness'.tl,
                  min: ReaderPreferences.readerBrightness.min.toDouble(),
                  max: ReaderPreferences.readerBrightness.max.toDouble(),
                  divisions: 16,
                  value:
                      (widget.brightnessPreview.brightness ??
                              _store.read<num>(
                                ReaderPreferences.readerBrightness,
                              ))
                          .toDouble(),
                  onChanged: (value) => _brightness(value.round()),
                ),
              ),
              Text(
                '${widget.brightnessPreview.brightness ?? _store.read<num>(ReaderPreferences.readerBrightness).round()}%',
              ),
            ],
          ),
        ),
      ],
    ),
    ReaderQuickSetting.direction => _toggle(
      'Reverse tap to turn Pages',
      ReaderPreferences.reverseTapToTurnPages,
    ),
    ReaderQuickSetting.zoom => _toggle(
      'Double tap to zoom',
      ReaderPreferences.enableDoubleTapToZoom,
    ),
    ReaderQuickSetting.animation => _toggle(
      'Page animation',
      ReaderPreferences.enablePageAnimation,
    ),
    ReaderQuickSetting.thumbnails => SwitchListTile(
      title: Text('Thumbnails'.tl),
      value: _store.read(ReaderPreferences.readerThumbnailState) == 'expanded',
      onChanged: (value) => unawaited(
        _save(
          ReaderPreferences.readerThumbnailState,
          value ? 'expanded' : 'collapsed',
        ),
      ),
    ),
  };

  @override
  Widget build(BuildContext context) => withSettingsSaveFeedback(
    protectSettings(
      AbsorbPointer(
        absorbing: !widget.isCurrent(),
        child: PopUpWidgetScaffold(
          title: 'Quick settings'.tl,
          onBack: leaveSettings,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  '${'Scope'.tl}: ${'This comic'.tl}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final item in readerQuickSettings) _item(item),
              const Divider(height: AppSizes.hairline),
              ListTile(
                title: Text('All settings'.tl),
                trailing: const Icon(Icons.arrow_forward),
                onTap: _allSettings,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    widget.brightnessPreview.removeListener(_refresh);
    super.dispose();
  }
}
