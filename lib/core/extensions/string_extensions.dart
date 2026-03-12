extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String capitalizeAll() {
    return split(' ').map((str) => str.capitalize()).join(' ');
  }
}
