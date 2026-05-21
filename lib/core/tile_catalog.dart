import 'package:flutter/material.dart';

class TileArt {
  const TileArt(this.icon, this.color);
  final IconData icon;
  final Color color;
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
