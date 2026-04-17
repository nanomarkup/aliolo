import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/core/utils/session_bucket_sampler.dart';

void main() {
  group('SessionBucketSampler', () {
    test('sampleBucket clamps to the requested size', () {
      final items = [1, 2, 3, 4, 5];
      final sample = SessionBucketSampler.sampleBucket(
        items,
        3,
        random: Random(1),
      );

      expect(sample, hasLength(3));
      expect(sample.toSet().length, 3);
      expect(sample.every(items.contains), isTrue);
    });

    test('takeRandom drains the bucket without repeats', () {
      final bucket = [1, 2, 3, 4];
      final random = Random(1);
      final seen = <int>[];

      while (bucket.isNotEmpty) {
        seen.add(SessionBucketSampler.takeRandom(bucket, random: random)!);
      }

      expect(bucket, isEmpty);
      expect(seen, hasLength(4));
      expect(seen.toSet().length, 4);
    });
  });
}
