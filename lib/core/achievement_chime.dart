import 'dart:math' as math;
import 'dart:typed_data';

/// Original 440 ms reward chime. Soft overlapping E/B/E partials, rounded
/// attacks and a silent tail; no samples, noise, bright fanfare or randomness.
Uint8List buildAchievementChime() {
  const rate = 22050;
  const count = 9702;
  final bytes = Uint8List(44 + count * 2);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + 4, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    final t = i / rate;
    final tail = ((count - 1 - i) / (rate * .075)).clamp(0.0, 1.0);
    final fade = .5 - .5 * math.cos(math.pi * tail);
    var sample = 0.0;
    for (final note in const [
      (329.63, 0.0, .18),
      (493.88, .045, .10),
      (659.25, .09, .05)
    ]) {
      final age = t - note.$2;
      if (age < 0) continue;
      final attack = (age / .016).clamp(0.0, 1.0);
      final envelope =
          (.5 - .5 * math.cos(math.pi * attack)) * math.exp(-age * 7);
      sample += note.$3 *
          envelope *
          (math.sin(2 * math.pi * note.$1 * age) +
              .10 * math.sin(4 * math.pi * note.$1 * age));
    }
    data.setInt16(44 + i * 2, (32767 * sample * fade).round(), Endian.little);
  }
  return bytes;
}
