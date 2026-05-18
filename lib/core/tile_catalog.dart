import 'package:flutter/material.dart';

class TileArt {
  const TileArt(this.emoji, this.color);
  final String emoji;
  final Color color;
}

const tileCatalog = <String, TileArt>{
  'apple': TileArt('🍎', Color(0xFFFF6B6B)),
  'banana': TileArt('🍌', Color(0xFFFFD166)),
  'berry': TileArt('🫐', Color(0xFF6C63FF)),
  'carrot': TileArt('🥕', Color(0xFFFF9F43)),
  'star': TileArt('⭐', Color(0xFFFFC857)),
  'shell': TileArt('🐚', Color(0xFFFFB3C7)),
  'flower': TileArt('🌸', Color(0xFFFF8FAB)),
  'moon': TileArt('🌙', Color(0xFF7D8CFF)),
  'gem': TileArt('💎', Color(0xFF4ECDC4)),
  'leaf': TileArt('🍃', Color(0xFF76D275)),
  'candy': TileArt('🍬', Color(0xFFB388FF)),
  'heart': TileArt('💖', Color(0xFFFF5C8A)),
  'sun': TileArt('☀️', Color(0xFFFFB703)),
  'drop': TileArt('💧', Color(0xFF48CAE4)),
  'clover': TileArt('☘️', Color(0xFF52B788)),
};
