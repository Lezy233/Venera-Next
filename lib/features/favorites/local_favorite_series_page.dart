import 'dart:async';

import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/features/favorites/favorite_models.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/translations.dart';

class LocalFavoriteSeriesPage extends StatefulWidget {
  const LocalFavoriteSeriesPage({
    required this.seriesId,
    required this.showFolders,
    super.key,
  });

  final String seriesId;
  final VoidCallback showFolders;

  @override
  State<LocalFavoriteSeriesPage> createState() =>
      _LocalFavoriteSeriesPageState();
}

class _LocalFavoriteSeriesPageState extends State<LocalFavoriteSeriesPage> {
  Future<void> _addComics() async {
    final manager = FavoritesScope.read(context);
    final current = manager.seriesMemberIdentities(widget.seriesId).toSet();
    final available = manager.getAllComics().where((comic) {
      return !current.contains((comic.id, comic.type.value));
    }).toList();
    final selected = <FavoriteItem>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add comics to series'.tl),
          content: SizedBox(
            width: 420,
            height: 420,
            child: available.isEmpty
                ? Center(child: Text('No comics available'.tl))
                : ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final comic = available[index];
                      return CheckboxListTile(
                        value: selected.contains(comic),
                        title: Text(comic.name),
                        subtitle: Text(comic.author),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selected.add(comic);
                          } else {
                            selected.remove(comic);
                          }
                        }),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tl),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add'.tl),
            ),
          ],
        ),
      ),
    );
    if (result == true && selected.isNotEmpty && mounted) {
      await manager.addToSeries(widget.seriesId, selected);
    }
  }

  List<MenuEntry> _menu(FavoriteItem comic) => [
    MenuEntry(
      icon: Icons.remove_circle_outline,
      text: 'Remove from series'.tl,
      onClick: () => unawaited(
        FavoritesScope.read(context).removeFromSeries(widget.seriesId, [comic]),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final manager = FavoritesScope.read(context);
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final series = manager.seriesById(widget.seriesId);
        final comics = manager.getSeriesComics(widget.seriesId);
        return CustomScrollView(
          slivers: [
            SliverAppbar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Folders'.tl,
                onPressed: widget.showFolders,
              ),
              title: Text(series?.name ?? 'Series'.tl),
              actions: [
                IconButton(
                  icon: const Icon(Icons.playlist_add),
                  tooltip: 'Add comics to series'.tl,
                  onPressed: _addComics,
                ),
              ],
            ),
            if (comics.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No comics in this series'.tl)),
                ),
              )
            else
              SliverGridComics(
                comics: comics,
                useFavoriteDisplaySettings: true,
                menuBuilder: (comic) => _menu(comic as FavoriteItem),
              ),
          ],
        );
      },
    );
  }
}
