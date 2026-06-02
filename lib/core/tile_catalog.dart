import 'package:flutter/material.dart';

class TileArt {
  const TileArt(this.icon, this.color, [this.label]);
  final IconData icon;
  final Color color;
  final String? label;
}

enum TileVisualTheme { garden, ocean, candy, space }

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
  }
}

TileVisualTheme tileVisualThemeForLevel(int level) {
  if (level <= 10) return TileVisualTheme.garden;
  if (level <= 20) return TileVisualTheme.ocean;
  if (level <= 30) return TileVisualTheme.candy;
  return TileVisualTheme.space;
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
