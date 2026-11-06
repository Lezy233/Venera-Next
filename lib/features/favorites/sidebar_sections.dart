import 'package:flutter/foundation.dart';

enum FavoriteSidebarSection { local, series, network }

/// Page-owned navigation preference shared with the transient folder chooser.
class FavoriteSidebarSections extends ValueNotifier<Map<String, bool>> {
  static const storageKey = 'favoritesSidebarSections';

  FavoriteSidebarSections(Object? stored)
    : super({
        for (final section in FavoriteSidebarSection.values)
          section.name: stored is Map && stored[section.name] is bool
              ? stored[section.name] as bool
              : true,
      });

  bool expanded(FavoriteSidebarSection section) => value[section.name]!;

  void setExpanded(FavoriteSidebarSection section, bool expanded) {
    if (this.expanded(section) == expanded) return;
    value = {...value, section.name: expanded};
  }

  static void merge(Map<String, dynamic> draft, Map<String, bool> snapshot) {
    final previous = draft[storageKey];
    draft[storageKey] = {if (previous is Map) ...previous, ...snapshot};
  }
}
