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
  'apple': TileArt(Icons.apple_rounded, Color(0xFFFF6B6B)),
  'banana': TileArt(Icons.local_dining_rounded, Color(0xFFFF5C8A)),
  'berry': TileArt(Icons.local_florist_rounded, Color(0xFFFF8FAB)),
  'carrot': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF76D275)),
  'star': TileArt(Icons.bug_report_rounded, Color(0xFFA855F7)),
  'shell': TileArt(Icons.apple_rounded, Color(0xFFE84855)),
  'flower': TileArt(Icons.local_dining_rounded, Color(0xFFFF7AA2)),
  'moon': TileArt(Icons.local_florist_rounded, Color(0xFFFFC857)),
  'gem': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF52B788)),
  'leaf': TileArt(Icons.bug_report_rounded, Color(0xFF7C3AED)),
  'candy': TileArt(Icons.apple_rounded, Color(0xFFFF466D)),
  'heart': TileArt(Icons.local_dining_rounded, Color(0xFFFF8FAB)),
  'sun': TileArt(Icons.local_florist_rounded, Color(0xFFFFB703)),
  'drop': TileArt(Icons.energy_savings_leaf_rounded, Color(0xFF2ECC71)),
  'clover': TileArt(Icons.bug_report_rounded, Color(0xFFB388FF)),
};

const _oceanCatalog = <String, TileArt>{
  'apple': TileArt(Icons.trip_origin_rounded, Color(0xFFFFB3C7)),
  'banana': TileArt(Icons.set_meal_rounded, Color(0xFF00B4D8)),
  'berry': TileArt(Icons.waves_rounded, Color(0xFF48CAE4)),
  'carrot': TileArt(Icons.filter_vintage_rounded, Color(0xFFFF8FAB)),
  'star': TileArt(Icons.pets_rounded, Color(0xFF0077B6)),
  'shell': TileArt(Icons.trip_origin_rounded, Color(0xFFFFD6E8)),
  'flower': TileArt(Icons.set_meal_rounded, Color(0xFF00C2FF)),
  'moon': TileArt(Icons.waves_rounded, Color(0xFF90E0EF)),
  'gem': TileArt(Icons.filter_vintage_rounded, Color(0xFFFF6B6B)),
  'leaf': TileArt(Icons.pets_rounded, Color(0xFF0096C7)),
  'candy': TileArt(Icons.trip_origin_rounded, Color(0xFFFFB3C7)),
  'heart': TileArt(Icons.set_meal_rounded, Color(0xFF00B4D8)),
  'sun': TileArt(Icons.waves_rounded, Color(0xFF00A6FB)),
  'drop': TileArt(Icons.filter_vintage_rounded, Color(0xFFFF9F43)),
  'clover': TileArt(Icons.pets_rounded, Color(0xFF74C0FC)),
};

const _candyCatalog = <String, TileArt>{
  'apple': TileArt(Icons.radio_button_checked_rounded, Color(0xFFFF5C8A)),
  'banana': TileArt(Icons.circle_rounded, Color(0xFFB388FF)),
  'berry': TileArt(Icons.donut_large_rounded, Color(0xFFFF9F43)),
  'carrot': TileArt(Icons.cookie_rounded, Color(0xFFD08C60)),
  'star': TileArt(Icons.view_comfy_rounded, Color(0xFF8D5524)),
  'shell': TileArt(Icons.radio_button_checked_rounded, Color(0xFFFF8FAB)),
  'flower': TileArt(Icons.circle_rounded, Color(0xFFFFC857)),
  'moon': TileArt(Icons.donut_large_rounded, Color(0xFFFFD166)),
  'gem': TileArt(Icons.cookie_rounded, Color(0xFFE8A87C)),
  'leaf': TileArt(Icons.view_comfy_rounded, Color(0xFF7B3F00)),
  'candy': TileArt(Icons.radio_button_checked_rounded, Color(0xFFFF6B6B)),
  'heart': TileArt(Icons.circle_rounded, Color(0xFF6C63FF)),
  'sun': TileArt(Icons.donut_large_rounded, Color(0xFFFFB703)),
  'drop': TileArt(Icons.cookie_rounded, Color(0xFFFF9F43)),
  'clover': TileArt(Icons.view_comfy_rounded, Color(0xFF6F4E37)),
};

const _spaceCatalog = <String, TileArt>{
  'apple': TileArt(Icons.star_rounded, Color(0xFFFFC857)),
  'banana': TileArt(Icons.dark_mode_rounded, Color(0xFF7D8CFF)),
  'berry': TileArt(Icons.public_rounded, Color(0xFF4ECDC4)),
  'carrot': TileArt(Icons.rocket_launch_rounded, Color(0xFFFF8F2A)),
  'star': TileArt(Icons.auto_awesome_rounded, Color(0xFFB388FF)),
  'shell': TileArt(Icons.star_rounded, Color(0xFFFFE577)),
  'flower': TileArt(Icons.dark_mode_rounded, Color(0xFF90CAF9)),
  'moon': TileArt(Icons.public_rounded, Color(0xFF7D8CFF)),
  'gem': TileArt(Icons.rocket_launch_rounded, Color(0xFFFF6B6B)),
  'leaf': TileArt(Icons.auto_awesome_rounded, Color(0xFFA855F7)),
  'candy': TileArt(Icons.star_rounded, Color(0xFFFFB703)),
  'heart': TileArt(Icons.dark_mode_rounded, Color(0xFFBDE0FE)),
  'sun': TileArt(Icons.public_rounded, Color(0xFF66D4FF)),
  'drop': TileArt(Icons.rocket_launch_rounded, Color(0xFFFF5C8A)),
  'clover': TileArt(Icons.auto_awesome_rounded, Color(0xFFB388FF)),
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
  final index = tileCatalog.keys.toList().indexOf(type);
  if (index == -1) return _titleCase(type);

  switch (theme) {
    case TileVisualTheme.garden:
      return const [
        'Apple',
        'Strawberry',
        'Flower',
        'Leaf',
        'Butterfly'
      ][index % 5];
    case TileVisualTheme.ocean:
      return const ['Shell', 'Fish', 'Wave', 'Coral', 'Dolphin'][index % 5];
    case TileVisualTheme.candy:
      return const [
        'Lollipop',
        'Candy',
        'Donut',
        'Cookie',
        'Chocolate'
      ][index % 5];
    case TileVisualTheme.space:
      return const ['Star', 'Moon', 'Planet', 'Rocket', 'Comet'][index % 5];
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return 'Goal';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
