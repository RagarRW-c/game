import 'package:flutter/material.dart';

/// Original code-native illustrations for the symbols absent from the sheet.
/// This is presentation metadata, never a saved matching identity.
enum TileIllustration {
  sun,
  seeds,
  clover,
  lagoon,
  starfish,
  gem,
  sugar,
  caramel,
  wafer,
  asteroids,
  portal,
  planet,
  heat,
  drop,
  relic,
  aurora,
  icicle,
  snowball,
  river,
  fern,
  flame,
  dawn,
  mist,
  bloom,
  amethyst,
}

class TileArt {
  const TileArt(this.icon, this.color, [this.label, this.assetPath])
      : illustration = null;
  const TileArt.illustrated(
      this.icon, this.color, this.label, this.illustration)
      : assetPath = null;
  final IconData icon;
  final Color color;
  final String? label;

  /// Complete approved tile (body and symbol), not a replacement matching ID.
  final String? assetPath;
  final TileIllustration? illustration;

  /// All surfaces share the same explicit image/illustration selection.
  bool get hasIllustratedSymbol => assetPath != null || illustration != null;
}

enum TileVisualTheme {
  garden,
  ocean,
  candy,
  space,
  desert,
  ice,
  jungle,
  volcano,
  dream,
  crystal,
}

// These keys are persisted match identities, not displayed symbol names.
// Keep their order: generators consume the catalog keys. The same twelve
// approved designs are used in every world; three IDs retain themed symbols.
const _approvedTileArt = <String, TileArt>{
  'apple': TileArt(Icons.apple_rounded, Color(0xFF76C728), 'Kiwi',
      'assets/tiles/approved/kiwi.png'),
  'banana': TileArt(Icons.park_rounded, Color(0xFF52B788), 'Palm',
      'assets/tiles/approved/palm.png'),
  'berry': TileArt(Icons.local_fire_department_rounded, Color(0xFFFF4438),
      'Chili', 'assets/tiles/approved/chili.png'),
  'carrot': TileArt(Icons.local_florist_rounded, Color(0xFFFF9F43), 'Carrot',
      'assets/tiles/approved/carrot.png'),
  'star': TileArt(Icons.bolt_rounded, Color(0xFFFFC857), 'Lightning',
      'assets/tiles/approved/lightning.png'),
  'shell': TileArt(Icons.receipt_rounded, Color(0xFFF0DEC4), 'Paper Roll',
      'assets/tiles/approved/paper_roll.png'),
  'flower': TileArt(Icons.local_florist_rounded, Color(0xFFFF8FAB), 'Lotus',
      'assets/tiles/approved/lotus.png'),
  'moon': TileArt(Icons.back_hand_rounded, Color(0xFF76D275), 'Mitten',
      'assets/tiles/approved/mitten.png'),
  'gem': TileArt(Icons.shopping_bag_rounded, Color(0xFFC58A43), 'Burlap Sack',
      'assets/tiles/approved/sack.png'),
  'leaf': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF76D275), 'Leaf',
      'assets/tiles/approved/leaf.png'),
  'candy': TileArt(Icons.flutter_dash_rounded, Color(0xFFFFD166), 'Chick',
      'assets/tiles/approved/chick.png'),
  'heart': TileArt(Icons.spa_rounded, Color(0xFF52B788), 'Monstera',
      'assets/tiles/approved/monstera.png'),
};

const tileCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(
      Icons.wb_sunny_rounded, Color(0xFFFFB703), null, TileIllustration.sun),
  'drop': TileArt.illustrated(
      Icons.water_drop_rounded, Color(0xFF48CAE4), null, TileIllustration.drop),
  'clover': TileArt.illustrated(
      Icons.spa_rounded, Color(0xFF52B788), null, TileIllustration.clover),
};

const _gardenCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(
      Icons.wb_sunny_rounded, Color(0xFFFFB703), 'Sun', TileIllustration.sun),
  'drop': TileArt.illustrated(
      Icons.grain_rounded, Color(0xFF7BC96F), 'Seeds', TileIllustration.seeds),
  'clover': TileArt.illustrated(Icons.cookie_rounded, Color(0xFF74C69D),
      'Clover', TileIllustration.clover),
};

const _oceanCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.public_rounded, Color(0xFF0077B6), 'Lagoon',
      TileIllustration.lagoon),
  'drop': TileArt.illustrated(Icons.flare_rounded, Color(0xFFFF9F43),
      'Starfish', TileIllustration.starfish),
  'clover': TileArt.illustrated(
      Icons.diamond_rounded, Color(0xFF4ECDC4), 'Gem', TileIllustration.gem),
};

const _candyCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.auto_awesome_rounded, Color(0xFFFFB703),
      'Sugar', TileIllustration.sugar),
  'drop': TileArt.illustrated(Icons.diamond_rounded, Color(0xFFFF9F43),
      'Caramel', TileIllustration.caramel),
  'clover': TileArt.illustrated(
      Icons.star_rounded, Color(0xFFFFD166), 'Wafer', TileIllustration.wafer),
};

const _spaceCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.grain_rounded, Color(0xFFBDE0FE),
      'Asteroids', TileIllustration.asteroids),
  'drop': TileArt.illustrated(Icons.filter_vintage_rounded, Color(0xFFFF5C8A),
      'Portal', TileIllustration.portal),
  'clover': TileArt.illustrated(Icons.circle_rounded, Color(0xFFB388FF),
      'Cosmos', TileIllustration.planet),
};

const _desertCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(
      Icons.flare_rounded, Color(0xFFFF9F1C), 'Heat', TileIllustration.heat),
  'drop': TileArt.illustrated(Icons.water_drop_rounded, Color(0xFF48CAE4),
      'Oasis', TileIllustration.drop),
  'clover': TileArt.illustrated(Icons.auto_awesome_rounded, Color(0xFFFFD166),
      'Relic', TileIllustration.relic),
};

const _iceCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.wb_twilight_rounded, Color(0xFFFFD166),
      'Aurora', TileIllustration.aurora),
  'drop': TileArt.illustrated(Icons.water_drop_rounded, Color(0xFF00B4D8),
      'Icicle', TileIllustration.icicle),
  'clover': TileArt.illustrated(Icons.circle_rounded, Color(0xFFD7F9FF),
      'Snowball', TileIllustration.snowball),
};

const _jungleCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.wb_sunny_rounded, Color(0xFFFFC857),
      'Sunbeam', TileIllustration.sun),
  'drop': TileArt.illustrated(
      Icons.waves_rounded, Color(0xFF00B4D8), 'River', TileIllustration.river),
  'clover': TileArt.illustrated(
      Icons.spa_rounded, Color(0xFF95D5B2), 'Fern', TileIllustration.fern),
};

const _volcanoCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.wb_sunny_rounded, Color(0xFFFFC857),
      'Magma Sun', TileIllustration.sun),
  'drop': TileArt.illustrated(Icons.water_drop_rounded, Color(0xFFFF9F43),
      'Molten Drop', TileIllustration.drop),
  'clover': TileArt.illustrated(Icons.auto_awesome_rounded, Color(0xFFFFD166),
      'Cinder', TileIllustration.flame),
};

const _dreamCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.wb_twilight_rounded, Color(0xFFFFD166),
      'Dawn', TileIllustration.dawn),
  'drop': TileArt.illustrated(Icons.water_drop_rounded, Color(0xFF90E0EF),
      'Mist', TileIllustration.mist),
  'clover': TileArt.illustrated(Icons.filter_vintage_rounded, Color(0xFFCDB4DB),
      'Bloom', TileIllustration.bloom),
};

const _crystalCatalog = <String, TileArt>{
  ..._approvedTileArt,
  'sun': TileArt.illustrated(Icons.wb_sunny_rounded, Color(0xFFFFD166),
      'Radiance', TileIllustration.sun),
  'drop': TileArt.illustrated(Icons.water_drop_rounded, Color(0xFF48CAE4),
      'Aqua', TileIllustration.drop),
  'clover': TileArt.illustrated(Icons.star_rounded, Color(0xFFE0AAFF),
      'Amethyst', TileIllustration.amethyst),
};

Map<String, TileArt> tileCatalogForTheme(TileVisualTheme theme) {
  switch (theme) {
    case TileVisualTheme.garden:
      return _gardenCatalog;
    case TileVisualTheme.ocean:
      return _oceanCatalog;
    case TileVisualTheme.candy:
      return _candyCatalog;
    case TileVisualTheme.space:
      return _spaceCatalog;
    case TileVisualTheme.desert:
      return _desertCatalog;
    case TileVisualTheme.ice:
      return _iceCatalog;
    case TileVisualTheme.jungle:
      return _jungleCatalog;
    case TileVisualTheme.volcano:
      return _volcanoCatalog;
    case TileVisualTheme.dream:
      return _dreamCatalog;
    case TileVisualTheme.crystal:
      return _crystalCatalog;
  }
}

TileVisualTheme tileVisualThemeForLevel(int level) {
  if (level <= 10) return TileVisualTheme.garden;
  if (level <= 20) return TileVisualTheme.ocean;
  if (level <= 30) return TileVisualTheme.candy;
  if (level <= 40) return TileVisualTheme.space;
  if (level <= 50) return TileVisualTheme.desert;
  if (level <= 60) return TileVisualTheme.ice;
  if (level <= 70) return TileVisualTheme.jungle;
  if (level <= 80) return TileVisualTheme.volcano;
  if (level <= 90) return TileVisualTheme.dream;
  return TileVisualTheme.crystal;
}

String tileLabelForTheme(TileVisualTheme theme, String type) {
  return tileCatalogForTheme(theme)[type]?.label ??
      tileCatalog[type]?.label ??
      _titleCase(type);
}

String _titleCase(String value) {
  if (value.isEmpty) return 'Goal';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
