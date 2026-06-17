import 'package:flutter/material.dart';

class TileArt {
  const TileArt(this.icon, this.color, [this.label]);
  final IconData icon;
  final Color color;
  final String? label;
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

const tileCatalog = <String, TileArt>{
  'apple': TileArt(Icons.apple_rounded, Color(0xFFFF6B6B)),
  'banana': TileArt(Icons.eco_rounded, Color(0xFFFFD166)),
  'berry': TileArt(Icons.grain_rounded, Color(0xFF6C63FF)),
  'carrot': TileArt(Icons.local_florist_rounded, Color(0xFFFF9F43)),
  'star': TileArt(Icons.star_rounded, Color(0xFFFFC857)),
  'shell': TileArt(Icons.waves_rounded, Color(0xFFFFB3C7)),
  'flower': TileArt(Icons.local_florist_rounded, Color(0xFFFF8FAB)),
  'moon': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF)),
  'gem': TileArt(Icons.diamond_rounded, Color(0xFF4ECDC4)),
  'leaf': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF76D275)),
  'candy': TileArt(Icons.cookie_rounded, Color(0xFFB388FF)),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF5C8A)),
  'sun': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFB703)),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFF48CAE4)),
  'clover': TileArt(Icons.spa_rounded, Color(0xFF52B788)),
};

const _gardenCatalog = <String, TileArt>{
  'apple': TileArt(Icons.apple_rounded, Color(0xFFFF6B6B), 'Apple'),
  'banana':
      TileArt(Icons.local_dining_rounded, Color(0xFFFF5C8A), 'Strawberry'),
  'berry': TileArt(Icons.local_florist_rounded, Color(0xFFFF8FAB), 'Flower'),
  'carrot':
      TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF76D275), 'Leaf'),
  'star': TileArt(Icons.bug_report_rounded, Color(0xFFA855F7), 'Butterfly'),
  'shell': TileArt(Icons.grass_rounded, Color(0xFF52B788), 'Grass'),
  'flower': TileArt(Icons.spa_rounded, Color(0xFFFF7AA2), 'Bloom'),
  'moon': TileArt(Icons.eco_rounded, Color(0xFF5DBB63), 'Sprout'),
  'gem': TileArt(Icons.park_rounded, Color(0xFF2ECC71), 'Tree'),
  'leaf': TileArt(Icons.forest_rounded, Color(0xFF2F9E44), 'Forest'),
  'candy': TileArt(Icons.filter_vintage_rounded, Color(0xFFFFC857), 'Daisy'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF8FAB), 'Heart'),
  'sun': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFB703), 'Sun'),
  'drop': TileArt(Icons.grain_rounded, Color(0xFF7BC96F), 'Seeds'),
  'clover': TileArt(Icons.cookie_rounded, Color(0xFF74C69D), 'Clover'),
};

const _oceanCatalog = <String, TileArt>{
  'apple': TileArt(Icons.beach_access_rounded, Color(0xFFFFB3C7), 'Shell'),
  'banana': TileArt(Icons.set_meal_rounded, Color(0xFF00B4D8), 'Fish'),
  'berry': TileArt(Icons.waves_rounded, Color(0xFF48CAE4), 'Wave'),
  'carrot': TileArt(Icons.filter_vintage_rounded, Color(0xFFFF8FAB), 'Coral'),
  'star': TileArt(Icons.pets_rounded, Color(0xFF0077B6), 'Dolphin'),
  'shell': TileArt(Icons.trip_origin_rounded, Color(0xFFFFD6E8), 'Pearl'),
  'flower': TileArt(Icons.bubble_chart_rounded, Color(0xFF90E0EF), 'Bubbles'),
  'moon': TileArt(Icons.anchor_rounded, Color(0xFF00A6FB), 'Anchor'),
  'gem': TileArt(Icons.sailing_rounded, Color(0xFF00C2FF), 'Sail'),
  'leaf': TileArt(Icons.water_rounded, Color(0xFF0096C7), 'Tide'),
  'candy': TileArt(Icons.scuba_diving_rounded, Color(0xFF74C0FC), 'Diver'),
  'heart': TileArt(Icons.water_drop_rounded, Color(0xFF38BDF8), 'Drop'),
  'sun': TileArt(Icons.public_rounded, Color(0xFF0077B6), 'Lagoon'),
  'drop': TileArt(Icons.flare_rounded, Color(0xFFFF9F43), 'Starfish'),
  'clover': TileArt(Icons.diamond_rounded, Color(0xFF4ECDC4), 'Gem'),
};

const _candyCatalog = <String, TileArt>{
  'apple': TileArt(
      Icons.radio_button_checked_rounded, Color(0xFFFF5C8A), 'Lollipop'),
  'banana': TileArt(Icons.circle_rounded, Color(0xFFB388FF), 'Candy'),
  'berry': TileArt(Icons.donut_large_rounded, Color(0xFFFF9F43), 'Donut'),
  'carrot': TileArt(Icons.cookie_rounded, Color(0xFFD08C60), 'Cookie'),
  'star': TileArt(Icons.view_comfy_rounded, Color(0xFF8D5524), 'Chocolate'),
  'shell': TileArt(Icons.icecream_rounded, Color(0xFFFF8FAB), 'Ice Cream'),
  'flower': TileArt(Icons.bakery_dining_rounded, Color(0xFFFFC857), 'Pastry'),
  'moon': TileArt(Icons.cake_rounded, Color(0xFFFFD166), 'Cupcake'),
  'gem': TileArt(Icons.celebration_rounded, Color(0xFFE8A87C), 'Sprinkles'),
  'leaf': TileArt(Icons.favorite_rounded, Color(0xFFFF6B9A), 'Gummy'),
  'candy': TileArt(Icons.trip_origin_rounded, Color(0xFFFF6B6B), 'Bonbon'),
  'heart': TileArt(Icons.bubble_chart_rounded, Color(0xFF6C63FF), 'Jelly'),
  'sun': TileArt(Icons.auto_awesome_rounded, Color(0xFFFFB703), 'Sugar'),
  'drop': TileArt(Icons.diamond_rounded, Color(0xFFFF9F43), 'Caramel'),
  'clover': TileArt(Icons.star_rounded, Color(0xFFFFD166), 'Wafer'),
};

const _spaceCatalog = <String, TileArt>{
  'apple': TileArt(Icons.star_rounded, Color(0xFFFFC857), 'Star'),
  'banana': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF), 'Moon'),
  'berry': TileArt(Icons.public_rounded, Color(0xFF4ECDC4), 'Planet'),
  'carrot': TileArt(Icons.rocket_launch_rounded, Color(0xFFFF8F2A), 'Rocket'),
  'star': TileArt(Icons.auto_awesome_rounded, Color(0xFFB388FF), 'Comet'),
  'shell': TileArt(Icons.satellite_alt_rounded, Color(0xFF90CAF9), 'Satellite'),
  'flower': TileArt(Icons.flare_rounded, Color(0xFFFFE577), 'Nova'),
  'moon': TileArt(Icons.bubble_chart_rounded, Color(0xFF7D8CFF), 'Nebula'),
  'gem': TileArt(Icons.trip_origin_rounded, Color(0xFFFF6B6B), 'Orbit'),
  'leaf':
      TileArt(Icons.radio_button_checked_rounded, Color(0xFFA855F7), 'Meteor'),
  'candy': TileArt(Icons.diamond_rounded, Color(0xFF66D4FF), 'Crystal'),
  'heart': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFB703), 'Solar'),
  'sun': TileArt(Icons.grain_rounded, Color(0xFFBDE0FE), 'Asteroids'),
  'drop': TileArt(Icons.filter_vintage_rounded, Color(0xFFFF5C8A), 'Portal'),
  'clover': TileArt(Icons.circle_rounded, Color(0xFFB388FF), 'Cosmos'),
};

const _desertCatalog = <String, TileArt>{
  'apple': TileArt(Icons.local_florist_rounded, Color(0xFF58A55C), 'Cactus'),
  'banana': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFB703), 'Sun'),
  'berry': TileArt(Icons.grain_rounded, Color(0xFFE9C46A), 'Sand'),
  'carrot': TileArt(Icons.bug_report_rounded, Color(0xFF8D5524), 'Scarab'),
  'star': TileArt(Icons.change_history_rounded, Color(0xFFD08C60), 'Pyramid'),
  'shell': TileArt(Icons.terrain_rounded, Color(0xFFC68642), 'Dune'),
  'flower': TileArt(Icons.explore_rounded, Color(0xFFF4A261), 'Compass'),
  'moon': TileArt(Icons.nightlight_rounded, Color(0xFF7D8CFF), 'Oasis Moon'),
  'gem': TileArt(Icons.diamond_rounded, Color(0xFF00B4D8), 'Turquoise'),
  'leaf': TileArt(Icons.spa_rounded, Color(0xFF70A37F), 'Palm'),
  'candy': TileArt(Icons.account_balance_rounded, Color(0xFFE0A458), 'Temple'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF6B6B), 'Charm'),
  'sun': TileArt(Icons.flare_rounded, Color(0xFFFF9F1C), 'Heat'),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFF48CAE4), 'Oasis'),
  'clover': TileArt(Icons.auto_awesome_rounded, Color(0xFFFFD166), 'Relic'),
};

const _iceCatalog = <String, TileArt>{
  'apple': TileArt(Icons.ac_unit_rounded, Color(0xFF90E0EF), 'Snowflake'),
  'banana': TileArt(Icons.pets_rounded, Color(0xFF0B4AA2), 'Penguin'),
  'berry': TileArt(Icons.terrain_rounded, Color(0xFFBDE0FE), 'Iceberg'),
  'carrot': TileArt(Icons.back_hand_rounded, Color(0xFFFFB3C7), 'Mitten'),
  'star': TileArt(Icons.diamond_rounded, Color(0xFF66D4FF), 'Crystal'),
  'shell': TileArt(Icons.water_rounded, Color(0xFF48CAE4), 'Frost'),
  'flower': TileArt(Icons.cloud_rounded, Color(0xFFE0F7FA), 'Snow Cloud'),
  'moon': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF), 'Polar Moon'),
  'gem': TileArt(Icons.auto_awesome_rounded, Color(0xFFBDE0FE), 'Glitter'),
  'leaf': TileArt(Icons.sledding_rounded, Color(0xFFFFF3B0), 'Sled'),
  'candy': TileArt(Icons.icecream_rounded, Color(0xFFB388FF), 'Ice Pop'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF8FAB), 'Warmth'),
  'sun': TileArt(Icons.wb_twilight_rounded, Color(0xFFFFD166), 'Aurora'),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFF00B4D8), 'Icicle'),
  'clover': TileArt(Icons.circle_rounded, Color(0xFFD7F9FF), 'Snowball'),
};

const _jungleCatalog = <String, TileArt>{
  'apple': TileArt(Icons.eco_rounded, Color(0xFFFFD166), 'Banana'),
  'banana': TileArt(Icons.flutter_dash_rounded, Color(0xFF06D6A0), 'Parrot'),
  'berry': TileArt(Icons.cable_rounded, Color(0xFF2D6A4F), 'Vine'),
  'carrot': TileArt(Icons.pets_rounded, Color(0xFFFF9F1C), 'Tiger'),
  'star': TileArt(Icons.park_rounded, Color(0xFF52B788), 'Palm'),
  'shell': TileArt(Icons.bug_report_rounded, Color(0xFFA855F7), 'Beetle'),
  'flower': TileArt(Icons.local_florist_rounded, Color(0xFFFF5C8A), 'Orchid'),
  'moon': TileArt(Icons.water_drop_rounded, Color(0xFF38BDF8), 'Rain'),
  'gem': TileArt(Icons.diamond_rounded, Color(0xFF4ECDC4), 'Jade'),
  'leaf': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF76D275), 'Leaf'),
  'candy': TileArt(Icons.grass_rounded, Color(0xFF2F9E44), 'Canopy'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF6B6B), 'Totem'),
  'sun': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFC857), 'Sunbeam'),
  'drop': TileArt(Icons.waves_rounded, Color(0xFF00B4D8), 'River'),
  'clover': TileArt(Icons.spa_rounded, Color(0xFF95D5B2), 'Fern'),
};

const _volcanoCatalog = <String, TileArt>{
  'apple':
      TileArt(Icons.local_fire_department_rounded, Color(0xFFFF5C33), 'Fire'),
  'banana': TileArt(Icons.whatshot_rounded, Color(0xFFFF7A1A), 'Lava'),
  'berry': TileArt(Icons.terrain_rounded, Color(0xFF6D4C41), 'Rock'),
  'carrot': TileArt(Icons.pets_rounded, Color(0xFFE63946), 'Dragon'),
  'star': TileArt(Icons.flare_rounded, Color(0xFFFFB703), 'Ember'),
  'shell': TileArt(Icons.terrain_rounded, Color(0xFF8D2F23), 'Crater'),
  'flower': TileArt(Icons.bolt_rounded, Color(0xFFFFD166), 'Spark'),
  'moon': TileArt(Icons.dark_mode_rounded, Color(0xFF3A0D0D), 'Ash Moon'),
  'gem': TileArt(Icons.diamond_rounded, Color(0xFFFF6B6B), 'Ruby'),
  'leaf': TileArt(Icons.cloud_rounded, Color(0xFF5E503F), 'Smoke'),
  'candy': TileArt(Icons.trip_origin_rounded, Color(0xFF2B2D42), 'Obsidian'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF8FAB), 'Core'),
  'sun': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFC857), 'Magma Sun'),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFFFF9F43), 'Molten Drop'),
  'clover': TileArt(Icons.auto_awesome_rounded, Color(0xFFFFD166), 'Cinder'),
};

const _dreamCatalog = <String, TileArt>{
  'apple': TileArt(Icons.cloud_rounded, Color(0xFFBDE0FE), 'Cloud'),
  'banana': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF), 'Moon'),
  'berry': TileArt(Icons.bedtime_rounded, Color(0xFFFFB3C7), 'Pillow'),
  'carrot': TileArt(Icons.auto_awesome_rounded, Color(0xFFFFD166), 'Sparkle'),
  'star': TileArt(Icons.flutter_dash_rounded, Color(0xFFE0F7FA), 'Feather'),
  'shell': TileArt(Icons.star_rounded, Color(0xFFFFC857), 'Wish'),
  'flower': TileArt(Icons.bubble_chart_rounded, Color(0xFFB388FF), 'Bubble'),
  'moon': TileArt(Icons.nightlight_rounded, Color(0xFF9B5DE5), 'Dream Moon'),
  'gem': TileArt(Icons.diamond_rounded, Color(0xFF80FFDB), 'Lucid Gem'),
  'leaf': TileArt(Icons.spa_rounded, Color(0xFF95D5B2), 'Soft Leaf'),
  'candy': TileArt(Icons.circle_rounded, Color(0xFFFFAFCC), 'Orb'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF5C8A), 'Memory'),
  'sun': TileArt(Icons.wb_twilight_rounded, Color(0xFFFFD166), 'Dawn'),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFF90E0EF), 'Mist'),
  'clover': TileArt(Icons.filter_vintage_rounded, Color(0xFFCDB4DB), 'Bloom'),
};

const _crystalCatalog = <String, TileArt>{
  'apple': TileArt(Icons.diamond_rounded, Color(0xFF4ECDC4), 'Gem'),
  'banana': TileArt(Icons.change_history_rounded, Color(0xFF66D4FF), 'Diamond'),
  'berry': TileArt(Icons.auto_awesome_rounded, Color(0xFFFFD166), 'Prism'),
  'carrot': TileArt(Icons.circle_rounded, Color(0xFFB388FF), 'Orb'),
  'star': TileArt(Icons.workspace_premium_rounded, Color(0xFFFFC857), 'Crown'),
  'shell': TileArt(Icons.hexagon_rounded, Color(0xFF90E0EF), 'Shard'),
  'flower': TileArt(Icons.flare_rounded, Color(0xFFFF8FAB), 'Gleam'),
  'moon': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF), 'Opal Moon'),
  'gem': TileArt(Icons.trip_origin_rounded, Color(0xFF80FFDB), 'Facet'),
  'leaf': TileArt(
      Icons.energy_savings_leaf_rounded, Color(0xFF95D5B2), 'Glassleaf'),
  'candy':
      TileArt(Icons.radio_button_checked_rounded, Color(0xFFFFAFCC), 'Pearl'),
  'heart': TileArt(Icons.favorite_rounded, Color(0xFFFF5C8A), 'Rose Quartz'),
  'sun': TileArt(Icons.wb_sunny_rounded, Color(0xFFFFD166), 'Radiance'),
  'drop': TileArt(Icons.water_drop_rounded, Color(0xFF48CAE4), 'Aqua'),
  'clover': TileArt(Icons.star_rounded, Color(0xFFE0AAFF), 'Amethyst'),
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
