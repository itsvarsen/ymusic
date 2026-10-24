import 'package:flutter_test/flutter_test.dart';
import 'package:ymusic/theme.dart';

void main() {
  test('formats durations', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });
}
