class NumberLocalizer {
  static const Map<String, List<String>> _digitMaps = {
    'ar': ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"],
    'hi': ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"],
  };

  static const List<String> _cjkChars = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
  static const List<String> _koChars = ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"];

  /// Localizes a number (0-99 supported) for specific visually distinct languages.
  static String localize(int number, String languageCode) {
    final lang = languageCode.toLowerCase();

    // Arabic and Hindi use digit-by-digit replacement
    if (_digitMaps.containsKey(lang)) {
      final digits = _digitMaps[lang]!;
      return number.toString().split('').map((d) {
        final val = int.tryParse(d);
        return val != null ? digits[val] : d;
      }).join('');
    }

    // Japanese and Chinese (Hanzi/Kanji up to 99)
    if (lang == 'ja' || lang == 'zh') {
      if (number == 0) return _cjkChars[0];
      if (number < 10) return _cjkChars[number];
      
      final tens = number ~/ 10;
      final ones = number % 10;
      String res = "";
      if (tens > 1) res += _cjkChars[tens];
      res += "十";
      if (ones > 0) res += _cjkChars[ones];
      return res;
    }

    // Korean (Sino-Korean up to 99)
    if (lang == 'ko') {
      if (number == 0) return _koChars[0];
      if (number < 10) return _koChars[number];
      
      final tens = number ~/ 10;
      final ones = number % 10;
      String res = "";
      if (tens > 1) res += _koChars[tens];
      res += "십";
      if (ones > 0) res += _koChars[ones];
      return res;
    }

    // Default to standard Western digits
    return number.toString();
  }

  /// Finds all numbers in a string and localizes them.
  static String localizeString(String text, String languageCode) {
    return text.replaceAllMapped(RegExp(r'\d+'), (match) {
      final number = int.tryParse(match.group(0)!);
      if (number != null) {
        return localize(number, languageCode);
      }
      return match.group(0)!;
    });
  }
}
