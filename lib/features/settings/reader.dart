import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/preferences.dart';
import 'package:venera_next/foundation/reader_preferences.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'reader_presets.dart';
import 'package:venera_next/foundation/reader_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/code.dart';
import 'package:venera_next/components/layout.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/features/reader/brightness.dart';
import 'package:venera_next/features/settings/setting_components.dart';
import 'package:venera_next/features/settings/reader_mode.dart';
import 'package:venera_next/features/settings/reader_brightness.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

enum ReaderSettingsScope { defaults, device, comic }

class ReaderSettings extends StatefulWidget {
  const ReaderSettings({
    super.key,
    this.onChanged,
    this.comicId,
    this.comicSource,
    this.currentReaderMode,
    this.isDetectingLayout,
    this.onDetectLayout,
    this.brightnessPreview,
  });

  final void Function(String key)? onChanged;
  final String? comicId;
  final String? comicSource;
  final String Function()? currentReaderMode;
  final bool Function()? isDetectingLayout;
  final Future<void> Function()? onDetectLayout;
  final ReaderBrightnessPreview? brightnessPreview;

  @override
  State<ReaderSettings> createState() => _ReaderSettingsState();
}

class _ReaderSettingsState extends SettingsSaveState<ReaderSettings> {
  late ReaderSettingsScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = widget.comicId != null && widget.comicSource != null
        ? ReaderSettingsScope.comic
        : ReaderSettingsScope.defaults;
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

  String? get _scopeComicId =>
      _scope == ReaderSettingsScope.comic ? widget.comicId : null;

  String? get _scopeComicSource =>
      _scope == ReaderSettingsScope.comic ? widget.comicSource : null;

  bool get _usesDeviceScope => _scope == ReaderSettingsScope.device;

  ReaderPreferenceScope get _preferenceScope => switch (_scope) {
    ReaderSettingsScope.defaults => ReaderPreferenceScope.global,
    ReaderSettingsScope.device => ReaderPreferenceScope.device,
    ReaderSettingsScope.comic => ReaderPreferenceScope.comic,
  };

  ReaderPreferenceStore get _store => ReaderPreferenceStore(
    settings: appdata.settings,
    scope: _preferenceScope,
    comicId: _scopeComicId,
    sourceKey: _scopeComicSource,
  );

  T _value<T extends Object>(Preference<T> preference) {
    if (_scope == ReaderSettingsScope.comic &&
        widget.comicId != null &&
        widget.comicSource != null &&
        identical(preference, ReaderPreferences.readerMode) &&
        widget.currentReaderMode != null) {
      return preference.normalize(widget.currentReaderMode!());
    }
    return _store.read(preference);
  }

  String get _activeReaderMode => _value(ReaderPreferences.readerMode);

  bool _usesMode(bool Function(String mode) matches) {
    if (matches(_activeReaderMode)) return true;
    if (_value(ReaderPreferences.autoReaderMode) != true) return false;
    return matches(_value(ReaderPreferences.pagedReaderMode)) ||
        matches(_value(ReaderPreferences.longStripReaderMode));
  }

  bool get _isVerticalFlowMode => _usesMode(
    (mode) => mode == 'waterfallTopToBottom' || mode == 'continuousTopToBottom',
  );

  bool _isChapterCommentsAtEndSupported() =>
      _value(ReaderPreferences.showChapterComments) == true &&
      _usesMode(
        (mode) => mode == 'galleryLeftToRight' || mode == 'galleryRightToLeft',
      );

  void _onShowChapterCommentsChanged() {
    setState(() {});
    widget.onChanged?.call('showChapterComments');
  }

  Future<void> _selectScope(ReaderSettingsScope scope) async {
    if (!acceptsSettingsChanges || savingSettings) return;
    final comicId = widget.comicId;
    final source = widget.comicSource;
    if (scope == ReaderSettingsScope.comic &&
        (comicId == null || source == null)) {
      return;
    }
    final previous = _scope;
    setState(() => _scope = scope);
    final ok = await saveSetting(
      'reader-scope',
      () => appdata.updateSettings((draft) {
        switch (scope) {
          case ReaderSettingsScope.defaults:
            draft.setEnabledDeviceSpecificSettings(false);
            if (comicId != null && source != null) {
              draft.setEnabledComicSpecificSettings(comicId, source, false);
            }
          case ReaderSettingsScope.device:
            draft.setEnabledDeviceSpecificSettings(true);
            if (comicId != null && source != null) {
              draft.setEnabledComicSpecificSettings(comicId, source, false);
            }
          case ReaderSettingsScope.comic:
            draft.setEnabledComicSpecificSettings(comicId!, source!, true);
        }
      }, sync: false),
      onSaved: () => widget.onChanged?.call('readerMode'),
      isCurrent: () => _scope == scope,
    );
    if (!ok && mounted && _scope == scope) {
      setState(() => _scope = previous);
    }
  }

  Future<void> _resetScope() async {
    final comicId = widget.comicId;
    final source = widget.comicSource;
    switch (_scope) {
      case ReaderSettingsScope.defaults:
        await saveSetting(
          'reader-reset-default',
          () => appdata.updateSettings((draft) {
            draft.resetGlobalReaderSettings();
          }),
          onSaved: () => widget.onChanged?.call('readerMode'),
        );
      case ReaderSettingsScope.device:
        await saveSetting(
          'reader-reset-device',
          () => appdata.updateSettings((draft) {
            draft.resetDeviceReaderSettings();
            draft.setEnabledDeviceSpecificSettings(true);
          }),
          onSaved: () => widget.onChanged?.call('readerMode'),
        );
      case ReaderSettingsScope.comic:
        if (comicId == null || source == null) return;
        await saveSetting(
          'reader-reset-comic',
          () => appdata.updateSettings((draft) {
            draft.resetComicReaderSettings('$comicId@$source');
            draft.setEnabledComicSpecificSettings(comicId, source, true);
          }),
          onSaved: () => widget.onChanged?.call('readerMode'),
        );
    }
  }

  String get _scopeDescription => switch (_scope) {
    ReaderSettingsScope.defaults => 'Changes apply to default settings.'.tl,
    ReaderSettingsScope.device => 'Changes apply to this device only.'.tl,
    ReaderSettingsScope.comic =>
      'Changes apply to this comic only. To change default settings, go to Settings → Reader.'
          .tl,
  };

  String get _resetLabel => switch (_scope) {
    ReaderSettingsScope.defaults => 'Reset defaults'.tl,
    ReaderSettingsScope.device => 'Reset this device'.tl,
    ReaderSettingsScope.comic => 'Reset this comic'.tl,
  };

  Widget _scopeSelector() {
    final comicAvailable = widget.comicId != null && widget.comicSource != null;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Scope'.tl, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<ReaderSettingsScope>(
              segments: [
                ButtonSegment(
                  value: ReaderSettingsScope.defaults,
                  label: Text('Default'.tl),
                ),
                ButtonSegment(
                  value: ReaderSettingsScope.device,
                  label: Text('This device'.tl),
                ),
                if (comicAvailable)
                  ButtonSegment(
                    value: ReaderSettingsScope.comic,
                    label: Text('This comic'.tl),
                  ),
              ],
              selected: {_scope},
              onSelectionChanged: savingSettings || !acceptsSettingsChanges
                  ? null
                  : (selection) => _selectScope(selection.first),
            ),
            const SizedBox(height: 8),
            Text(_scopeDescription),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: savingSettings || !acceptsSettingsChanges
                    ? null
                    : _resetScope,
                child: Text(_resetLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSettings() {
    return ReaderModeSettings(
      comicId: _scopeComicId,
      sourceKey: _scopeComicSource,
      scope: _preferenceScope,
      currentMode: widget.currentReaderMode,
      isDetecting: widget.isDetectingLayout,
      onDetect: widget.onDetectLayout,
      onChanged: () {
        widget.onChanged?.call('readerMode');
        _refresh();
      },
    ).toSliver();
  }

  Widget _thumbnailSettings() {
    final comicId = _scopeComicId;
    final source = _scopeComicSource;
    final specific = comicId != null && source != null;
    final device = _usesDeviceScope;
    final position = _value(ReaderPreferences.readerThumbnailPosition);
    final mode = _activeReaderMode;
    final topToBottom =
        mode == 'galleryTopToBottom' ||
        mode == 'continuousTopToBottom' ||
        mode == 'waterfallTopToBottom';
    void changed(String key) {
      setState(() {});
      widget.onChanged?.call(key);
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectSetting.reader(
            title: 'Thumbnails'.tl,
            preference: ReaderPreferences.readerThumbnailState,
            optionTranslation: {
              'expanded': 'Expanded'.tl,
              'collapsed': 'Collapsed'.tl,
            },
            onChanged: () => changed('readerThumbnailState'),
            comicId: specific ? comicId : null,
            comicSource: specific ? source : null,
            useDeviceSettings: device,
          ),
          SelectSetting.reader(
            title: 'Edge mode'.tl,
            preference: ReaderPreferences.readerThumbnailMode,
            optionTranslation: {'floating': 'Floating'.tl, 'fixed': 'Fixed'.tl},
            onChanged: () => changed('readerThumbnailMode'),
            comicId: specific ? comicId : null,
            comicSource: specific ? source : null,
            useDeviceSettings: device,
          ),
          SelectSetting.reader(
            title: 'Edge position'.tl,
            preference: ReaderPreferences.readerThumbnailPosition,
            optionTranslation: {
              'left': 'Left'.tl,
              'bottom': 'Bottom'.tl,
              'right': 'Right'.tl,
            },
            onChanged: () => changed('readerThumbnailPosition'),
            comicId: specific ? comicId : null,
            comicSource: specific ? source : null,
            useDeviceSettings: device,
          ),
          if (position == 'bottom' && topToBottom)
            SelectSetting.reader(
              title: 'Scroll direction'.tl,
              preference: ReaderPreferences.readerThumbnailScrollDirection,
              optionTranslation: {
                'rightToLeft': 'Right to left'.tl,
                'leftToRight': 'Left to right'.tl,
              },
              onChanged: () => changed('readerThumbnailScrollDirection'),
              comicId: specific ? comicId : null,
              comicSource: specific ? source : null,
              useDeviceSettings: device,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = protectSettings(
      SmoothCustomScrollView(
        // Keep nearby sections built so scope/brightness controls stay alive
        // while the long settings list scrolls.
        cacheExtent: 1200,
        slivers: [
          SliverAppbar(title: Text("Reading".tl)),
          _scopeSelector(),
          SettingPartTitle(title: "Reading Mode".tl, icon: Icons.view_module),
          _modeSettings(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'Reading mode presets'.tl,
                style: const TextStyle(fontSize: AppFontSize.title),
              ),
            ),
          ),
          ReaderPresetSelector(
            store: ReaderPresetStore(
              scope: _preferenceScope,
              comicId: _scopeComicId,
              sourceKey: _scopeComicSource,
            ),
            showManagement: true,
            onChanged: (key) {
              widget.onChanged?.call(key);
              _refresh();
            },
          ).toSliver(),
          SettingPartTitle(title: "Display".tl, icon: Icons.brightness_6),
          SwitchSetting.reader(
            title: "Page animation".tl,
            preference: ReaderPreferences.enablePageAnimation,
            onChanged: () {
              widget.onChanged?.call("enablePageAnimation");
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          ReaderBrightnessSetting(
            comicId: _scopeComicId,
            sourceKey: _scopeComicSource,
            scope: _preferenceScope,
            preview: widget.brightnessPreview,
            onChanged: widget.onChanged,
          ).toSliver(),
          SwitchSetting.reader(
            title: "Show Page Number".tl,
            preference: ReaderPreferences.showPageNumberInReader,
            onChanged: () {
              widget.onChanged?.call("showPageNumberInReader");
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SwitchSetting.reader(
            title: 'Show image pixel dimensions'.tl,
            preference: ReaderPreferences.showImageDimensions,
            onChanged: () => widget.onChanged?.call('showImageDimensions'),
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SwitchSetting.reader(
            title: "Show Chapter Comments".tl,
            preference: ReaderPreferences.showChapterComments,
            onChanged: _onShowChapterCommentsChanged,
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SliverAnimatedVisibility(
            visible: _isChapterCommentsAtEndSupported(),
            child: SwitchSetting.reader(
              title: "Show Comments at Chapter End".tl,
              preference: ReaderPreferences.showChapterCommentsAtEnd,
              onChanged: () {
                widget.onChanged?.call("showChapterCommentsAtEnd");
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SettingPartTitle(
            title: "Auto Reading".tl,
            icon: Icons.play_circle_outline,
          ),
          SliderSetting.reader(
            title: "Auto page turning interval (gallery)".tl,
            preference: ReaderPreferences.autoPageTurningInterval,
            valueFormatter: (value) => '${value.toInt()} s',
            onChanged: () => widget.onChanged?.call('autoPageTurningInterval'),
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SelectSetting.reader(
            title: 'Automatic scrolling (continuous and waterfall)'.tl,
            preference: ReaderPreferences.autoScrollStyle,
            optionTranslation: {
              'smooth': 'Smooth scrolling'.tl,
              'stepped': 'Step scrolling'.tl,
            },
            onChanged: () {
              setState(() {});
              widget.onChanged?.call('autoScrollStyle');
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          if (_value(ReaderPreferences.autoScrollStyle) == 'smooth')
            SliderSetting.reader(
              title: "Automatic scroll speed".tl,
              preference: ReaderPreferences.autoScrollSpeed,
              valueFormatter: (value) => '${value.toInt()} px/s',
              onChanged: () => widget.onChanged?.call('autoScrollSpeed'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
          if (_value(ReaderPreferences.autoScrollStyle) == 'stepped') ...[
            SliderSetting.reader(
              title: "Scroll steps per second".tl,
              preference: ReaderPreferences.autoScrollFrequency,
              valueFormatter: (value) => '${value.toInt()} /s',
              onChanged: () => widget.onChanged?.call('autoScrollFrequency'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
            SliderSetting.reader(
              title: "Distance per scroll step".tl,
              preference: ReaderPreferences.autoScrollDistance,
              valueFormatter: (value) => '${value.toInt()} px',
              onChanged: () => widget.onChanged?.call('autoScrollDistance'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
          ],
          SwitchSetting.reader(
            title: 'Continue automatically to the next chapter'.tl,
            preference: ReaderPreferences.autoReadingAcrossChapters,
            onChanged: () =>
                widget.onChanged?.call('autoReadingAcrossChapters'),
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SwitchSetting.reader(
            title: 'Skip unavailable images during automatic reading'.tl,
            subtitle:
                'Skip failed images at the normal pace; wait for loading images before continuing.'
                    .tl,
            preference: ReaderPreferences.autoReadingSkipUnavailableImages,
            onChanged: () {
              setState(() {});
              widget.onChanged?.call('autoReadingSkipUnavailableImages');
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          if (_value(ReaderPreferences.autoReadingSkipUnavailableImages))
            SliderSetting.reader(
              title: 'Wait for loading images (seconds)'.tl,
              preference: ReaderPreferences.autoReadingImageWaitSeconds,
              valueFormatter: (value) => '${value.toInt()} s',
              onChanged: () =>
                  widget.onChanged?.call('autoReadingImageWaitSeconds'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
          if (App.isAndroid || App.isIOS)
            SwitchSetting.reader(
              title: 'Keep screen on during automatic reading'.tl,
              preference: ReaderPreferences.autoReadingKeepScreenOn,
              onChanged: () =>
                  widget.onChanged?.call('autoReadingKeepScreenOn'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
          SettingPartTitle(title: "Thumbnails".tl, icon: Icons.view_sidebar),
          _thumbnailSettings(),
          SettingPartTitle(title: "Gestures".tl, icon: Icons.gesture),
          SwitchSetting.reader(
            title: "Tap to turn Pages".tl,
            preference: ReaderPreferences.enableTapToTurnPages,
            onChanged: () {
              widget.onChanged?.call("enableTapToTurnPages");
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SwitchSetting.reader(
            title: "Reverse tap to turn Pages".tl,
            preference: ReaderPreferences.reverseTapToTurnPages,
            onChanged: () {
              widget.onChanged?.call("reverseTapToTurnPages");
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SliverAnimatedVisibility(
            visible: _usesMode(
              (mode) =>
                  mode.startsWith('continuous') || mode.startsWith('waterfall'),
            ),
            child: SliderSetting.reader(
              title: "Mouse scroll speed".tl,
              preference: ReaderPreferences.readerScrollSpeed,
              onChanged: () {
                widget.onChanged?.call("readerScrollSpeed");
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SwitchSetting.reader(
            title: 'Double tap to zoom'.tl,
            preference: ReaderPreferences.enableDoubleTapToZoom,
            onChanged: () {
              setState(() {});
              widget.onChanged?.call('enableDoubleTapToZoom');
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SelectSetting.reader(
            title: 'Long press action'.tl,
            preference: ReaderPreferences.longPressAction,
            optionTranslation: {
              'zoom': 'Zoom image'.tl,
              'autoReading': 'Start or stop automatic reading'.tl,
              'none': 'No action'.tl,
            },
            onChanged: () {
              setState(() {});
              widget.onChanged?.call('longPressAction');
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SliverAnimatedVisibility(
            visible: _value(ReaderPreferences.longPressAction) == 'zoom',
            child: SelectSetting.reader(
              title: "Long press zoom position".tl,
              preference: ReaderPreferences.longPressZoomPosition,
              optionTranslation: {
                "press": "Press position".tl,
                "center": "Screen center".tl,
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          if (App.isAndroid)
            SwitchSetting.reader(
              title: 'Turn page by volume keys'.tl,
              preference: ReaderPreferences.enableTurnPageByVolumeKey,
              onChanged: () {
                widget.onChanged?.call('enableTurnPageByVolumeKey');
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ).toSliver(),
          SelectSetting.reader(
            title: "Quick collect image".tl,
            preference: ReaderPreferences.quickCollectImage,
            optionTranslation: {
              "No": "Not enable".tl,
              "DoubleTap": "Double Tap".tl,
              "Swipe": "Swipe".tl,
            },
            onChanged: () {
              widget.onChanged?.call("quickCollectImage");
            },
            help:
                "On the image browsing page, you can quickly collect images by sliding horizontally or vertically according to your reading mode"
                    .tl,
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SettingPartTitle(title: "Layout".tl, icon: Icons.view_quilt),
          SliverAnimatedVisibility(
            visible: _usesMode((mode) => mode.startsWith('gallery')),
            child: SliderSetting.reader(
              title:
                  "The number of pic in screen for landscape (Only Gallery Mode)"
                      .tl,
              preference: ReaderPreferences.readerScreenPicNumberForLandscape,
              onChanged: () {
                setState(() {});
                widget.onChanged?.call("readerScreenPicNumberForLandscape");
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SliverAnimatedVisibility(
            visible: _usesMode((mode) => mode.startsWith('gallery')),
            child: SliderSetting.reader(
              title:
                  "The number of pic in screen for portrait (Only Gallery Mode)"
                      .tl,
              preference: ReaderPreferences.readerScreenPicNumberForPortrait,
              onChanged: () {
                widget.onChanged?.call("readerScreenPicNumberForPortrait");
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SliverAnimatedVisibility(
            visible:
                _usesMode((mode) => mode.startsWith('gallery')) &&
                (_value(ReaderPreferences.readerScreenPicNumberForLandscape) >
                        1 ||
                    _value(ReaderPreferences.readerScreenPicNumberForPortrait) >
                        1),
            child: SwitchSetting.reader(
              title: "Show single image on first page".tl,
              preference: ReaderPreferences.showSingleImageOnFirstPage,
              onChanged: () {
                widget.onChanged?.call("showSingleImageOnFirstPage");
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SwitchSetting.reader(
            title: 'Limit image width'.tl,
            subtitle: 'When using Continuous(Top to Bottom) mode'.tl,
            preference: ReaderPreferences.limitImageWidth,
            onChanged: () {
              widget.onChanged?.call('limitImageWidth');
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SliverAnimatedVisibility(
            visible: _isVerticalFlowMode,
            child: SliderSetting.reader(
              title: 'Shrink strip comics (margin per side)'.tl,
              preference: ReaderPreferences.readerSideMargin,
              valueFormatter: (value) => '${value.toInt()}%',
              onChanged: () => widget.onChanged?.call('readerSideMargin'),
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SliverAnimatedVisibility(
            visible: _isVerticalFlowMode,
            child: SwitchSetting.reader(
              title: 'Split dual pages'.tl,
              subtitle:
                  'Only applies to Continuous and Waterfall (Top to Bottom) modes'
                      .tl,
              preference: ReaderPreferences.splitDualPage,
              onChanged: () {
                setState(() {});
                widget.onChanged?.call('splitDualPage');
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SliverAnimatedVisibility(
            visible:
                _isVerticalFlowMode &&
                _value(ReaderPreferences.splitDualPage) == true,
            child: SwitchSetting.reader(
              title: 'Swap split dual page order'.tl,
              subtitle:
                  'Turn this on when the split page order does not match the reading direction'
                      .tl,
              preference: ReaderPreferences.splitDualPageInvert,
              onChanged: () {
                widget.onChanged?.call('splitDualPageInvert');
              },
              comicId: _scopeComicId,
              comicSource: _scopeComicSource,
              useDeviceSettings: _usesDeviceScope,
            ),
          ),
          SettingPartTitle(title: "Advanced".tl, icon: Icons.build),
          SwitchSetting.reader(
            title: "E-Ink display refresh".tl,
            subtitle:
                "Flash the screen after page changes to reduce ghosting on E-Ink displays. Only applies to Gallery modes."
                    .tl,
            preference: ReaderPreferences.eInkRefreshEnabled,
            onChanged: () {
              setState(() {});
              widget.onChanged?.call("eInkRefreshEnabled");
            },
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
          SliverAnimatedVisibility(
            visible: _value(ReaderPreferences.eInkRefreshEnabled) == true,
            child: Column(
              children: [
                SliderSetting.reader(
                  title: "Refresh flash duration".tl,
                  preference: ReaderPreferences.eInkRefreshDuration,
                  valueFormatter: (value) => '${value.toInt()} ms',
                  onChanged: () {
                    widget.onChanged?.call("eInkRefreshDuration");
                  },
                  comicId: _scopeComicId,
                  comicSource: _scopeComicSource,
                  useDeviceSettings: _usesDeviceScope,
                ),
                SliderSetting.reader(
                  title: "Refresh interval".tl,
                  preference: ReaderPreferences.eInkRefreshInterval,
                  valueFormatter: (value) => value.toInt().toString(),
                  onChanged: () {
                    widget.onChanged?.call("eInkRefreshInterval");
                  },
                  comicId: _scopeComicId,
                  comicSource: _scopeComicSource,
                  useDeviceSettings: _usesDeviceScope,
                ),
                SelectSetting.reader(
                  title: "Refresh flash style".tl,
                  preference: ReaderPreferences.eInkRefreshStyle,
                  optionTranslation: {
                    "black": "Black".tl,
                    "white": "White".tl,
                    "whiteThenBlack": "White then black".tl,
                  },
                  onChanged: () {
                    widget.onChanged?.call("eInkRefreshStyle");
                  },
                  comicId: _scopeComicId,
                  comicSource: _scopeComicSource,
                  useDeviceSettings: _usesDeviceScope,
                ),
              ],
            ),
          ),
          CallbackSetting(
            title: "Custom Image Processing".tl,
            callback: () => context.to(() => _CustomImageProcessing()),
            actionTitle: "Edit".tl,
          ).toSliver(),
          SliderSetting.reader(
            title: "Number of images preloaded".tl,
            preference: ReaderPreferences.preloadImageCount,
            comicId: _scopeComicId,
            comicSource: _scopeComicSource,
            useDeviceSettings: _usesDeviceScope,
          ).toSliver(),
        ],
      ),
    );
    return withSettingsSaveFeedback(body);
  }
}

class _CustomImageProcessing extends StatefulWidget {
  const _CustomImageProcessing();

  @override
  State<_CustomImageProcessing> createState() => __CustomImageProcessingState();
}

class __CustomImageProcessingState
    extends SettingsSaveState<_CustomImageProcessing> {
  var current = '';

  @override
  void initState() {
    super.initState();
    current = GlobalPreferenceStore(
      appdata.settings,
    ).read(ImageProcessingPreferences.script);
  }

  void _saveCode(String value) {
    if (!acceptsSettingsChanges) return;
    current = value;
    saveSetting(
      ImageProcessingPreferences.script.key,
      () => appdata.updateSettings((draft) {
        GlobalPreferenceStore(
          draft,
        ).write(ImageProcessingPreferences.script, value);
      }),
    );
  }

  int resetKey = 0;

  @override
  Widget build(BuildContext context) {
    return protectSettings(
      Scaffold(
        appBar: Appbar(
          title: Text("Custom Image Processing".tl),
          actions: [
            settingsSaveStatus,
            TextButton(
              onPressed: () {
                if (!acceptsSettingsChanges) return;
                _saveCode(defaultCustomImageProcessing);
                resetKey++;
                setState(() {});
              },
              child: Text("Reset".tl),
            ),
          ],
        ),
        body: Column(
          children: [
            SwitchSetting(
              title: "Enable".tl,
              settingKey: ImageProcessingPreferences.enabled.key,
              preference: ImageProcessingPreferences.enabled,
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: context.colorScheme.outlineVariant),
                ),
                child: SizedBox.expand(
                  child: CodeEditor(
                    key: ValueKey(resetKey),
                    initialValue: current,
                    onChanged: _saveCode,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
