import 'package:flutter_test/flutter_test.dart';
import 'package:dictation_app/models/models.dart';

void main() {
  test('categories list is non-empty', () {
    expect(kCategories, isNotEmpty);
    expect(kCategories.first.url,
        startsWith('https://dailydictation.com/exercises/'));
  });
}
