import 'dart:math';

class SessionBucketSampler {
  static List<T> sampleBucket<T>(
    List<T> items,
    int size, {
    Random? random,
  }) {
    if (size <= 0 || items.isEmpty) return [];

    final bucket = List<T>.from(items);
    bucket.shuffle(random ?? Random());

    if (bucket.length <= size) return bucket;
    return bucket.sublist(0, size);
  }

  static T? takeRandom<T>(
    List<T> bucket, {
    Random? random,
  }) {
    if (bucket.isEmpty) return null;

    final rng = random ?? Random();
    final index = rng.nextInt(bucket.length);
    return bucket.removeAt(index);
  }
}
