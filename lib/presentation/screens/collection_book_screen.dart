import 'package:flutter/material.dart';

import '../../core/tile_catalog.dart';
import '../../main.dart';
import '../theme/game_theme.dart';
import '../theme/world_theme.dart';
import '../widgets/game_ui.dart';

class CollectionBookScreen extends StatefulWidget {
  const CollectionBookScreen({super.key});

  static const route = '/collection-book';

  @override
  State<CollectionBookScreen> createState() => _CollectionBookScreenState();
}

class _CollectionBookScreenState extends State<CollectionBookScreen> {
  late Future<Set<String>> _discoveredFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _discoveredFuture =
        AppScope.of(context).progressRepository.discoveredCollectionKeys();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(
                title: 'Collection Book',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: FutureBuilder<Set<String>>(
                  future: _discoveredFuture,
                  builder: (context, snapshot) {
                    final discovered = snapshot.data ?? const <String>{};
                    return ListView.separated(
                      padding: const EdgeInsets.all(GameSpacing.lg),
                      itemCount: _collections.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GameSpacing.lg),
                      itemBuilder: (context, index) {
                        return _CollectionWorldCard(
                          collection: _collections[index],
                          discovered: discovered,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionDefinition {
  const _CollectionDefinition({
    required this.key,
    required this.title,
    required this.theme,
    required this.worldTheme,
  });

  final String key;
  final String title;
  final TileVisualTheme theme;
  final WorldVisualTheme worldTheme;
}

const _collectionTileTypes = <String>[
  'apple',
  'banana',
  'berry',
  'carrot',
  'star',
];

const _collections = <_CollectionDefinition>[
  _CollectionDefinition(
    key: 'garden',
    title: 'Garden Collection',
    theme: TileVisualTheme.garden,
    worldTheme: WorldThemes.garden,
  ),
  _CollectionDefinition(
    key: 'ocean',
    title: 'Ocean Collection',
    theme: TileVisualTheme.ocean,
    worldTheme: WorldThemes.ocean,
  ),
  _CollectionDefinition(
    key: 'candy',
    title: 'Candy Collection',
    theme: TileVisualTheme.candy,
    worldTheme: WorldThemes.candy,
  ),
  _CollectionDefinition(
    key: 'space',
    title: 'Space Collection',
    theme: TileVisualTheme.space,
    worldTheme: WorldThemes.space,
  ),
  _CollectionDefinition(
    key: 'desert',
    title: 'Desert Collection',
    theme: TileVisualTheme.desert,
    worldTheme: WorldThemes.desert,
  ),
  _CollectionDefinition(
    key: 'ice',
    title: 'Ice Collection',
    theme: TileVisualTheme.ice,
    worldTheme: WorldThemes.ice,
  ),
  _CollectionDefinition(
    key: 'jungle',
    title: 'Jungle Collection',
    theme: TileVisualTheme.jungle,
    worldTheme: WorldThemes.jungle,
  ),
  _CollectionDefinition(
    key: 'volcano',
    title: 'Volcano Collection',
    theme: TileVisualTheme.volcano,
    worldTheme: WorldThemes.volcano,
  ),
  _CollectionDefinition(
    key: 'dream',
    title: 'Dream Collection',
    theme: TileVisualTheme.dream,
    worldTheme: WorldThemes.dream,
  ),
  _CollectionDefinition(
    key: 'crystal',
    title: 'Crystal Collection',
    theme: TileVisualTheme.crystal,
    worldTheme: WorldThemes.crystal,
  ),
];

class _CollectionWorldCard extends StatelessWidget {
  const _CollectionWorldCard({
    required this.collection,
    required this.discovered,
  });

  final _CollectionDefinition collection;
  final Set<String> discovered;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _collectionTileTypes
        .where((type) => discovered.contains(_collectionKey(type)))
        .length;
    return GameCard(
      gradient: collection.worldTheme.boardGradient,
      borderColor: collection.worldTheme.secondaryAccent,
      shadow: GameShadows.glow(collection.worldTheme.primaryAccent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                collection.worldTheme.decorationIcons.first,
                color: collection.worldTheme.primaryAccent,
                size: 30,
              ),
              const SizedBox(width: GameSpacing.sm),
              Expanded(
                child: Text(
                  collection.title,
                  style: GameTextStyles.h2.copyWith(fontSize: 23),
                ),
              ),
              GameBadge(
                gradient: GameGradients.darkBadge,
                child: Text(
                  '$unlockedCount/${_collectionTileTypes.length}',
                  style: GameTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: GameSpacing.sm),
          ClipRRect(
            borderRadius: GameRadius.smallRadius,
            child: LinearProgressIndicator(
              minHeight: 8,
              value: unlockedCount / _collectionTileTypes.length,
              backgroundColor: GameColors.borderBlue,
              color: collection.worldTheme.primaryAccent,
            ),
          ),
          const SizedBox(height: GameSpacing.lg),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            mainAxisSpacing: GameSpacing.sm,
            crossAxisSpacing: GameSpacing.sm,
            childAspectRatio: 0.72,
            children: [
              for (final type in _collectionTileTypes)
                _CollectionEntryTile(
                  theme: collection.theme,
                  type: type,
                  unlocked: discovered.contains(_collectionKey(type)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _collectionKey(String type) => '${collection.key}_$type';
}

class _CollectionEntryTile extends StatelessWidget {
  const _CollectionEntryTile({
    required this.theme,
    required this.type,
    required this.unlocked,
  });

  final TileVisualTheme theme;
  final String type;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final art = tileCatalogForTheme(theme)[type];
    final label = tileLabelForTheme(theme, type);
    return AnimatedOpacity(
      duration: GameDurations.normal,
      opacity: unlocked ? 1 : 0.58,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient:
                    unlocked ? GameGradients.panel : GameGradients.disabled,
                borderRadius: GameRadius.mediumRadius,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow:
                    unlocked ? GameShadows.medium() : GameShadows.light(),
              ),
              child: Icon(
                unlocked ? art?.icon ?? Icons.help_rounded : Icons.help_rounded,
                color: unlocked ? art?.color ?? GameColors.ink : Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: GameSpacing.xs),
          Text(
            unlocked ? label : 'Locked',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GameTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
