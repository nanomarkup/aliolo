import 'package:flutter/material.dart';

class DivisionGrid extends StatelessWidget {
  final int a;
  final int b;
  final String languageCode;
  final Color? color;
  final double fontSize;

  const DivisionGrid({
    super.key,
    required this.a,
    required this.b,
    required this.languageCode,
    this.color,
    this.fontSize = 100,
  });

  String _getLocalizedDigit(int val) {
    const Map<int, Map<String, String>> specialNums = {
      0: {'ar': '٠', 'hi': '०', 'zh': '零', 'ja': '零', 'ko': '영'},
      1: {'ar': '١', 'hi': '१', 'zh': '一', 'ja': '一', 'ko': '일'},
      2: {'ar': '٢', 'hi': '२', 'zh': '二', 'ja': '二', 'ko': '이'},
      3: {'ar': '٣', 'hi': '٣', 'zh': '三', 'ja': '三', 'ko': '삼'},
      4: {'ar': '٤', 'hi': '٤', 'zh': '四', 'ja': '四', 'ko': '사'},
      5: {'ar': '٥', 'hi': '٥', 'zh': '五', 'ja': '五', 'ko': '오'},
      6: {'ar': '٦', 'hi': '٦', 'zh': '六', 'ja': '六', 'ko': '육'},
      7: {'ar': '٧', 'hi': '٧', 'zh': '七', 'ja': '七', 'ko': '칠'},
      8: {'ar': '٨', 'hi': '٨', 'zh': '八', 'ja': '八', 'ko': '팔'},
      9: {'ar': '٩', 'hi': '٩', 'zh': '九', 'ja': '九', 'ko': '구'},
      10: {'ar': '١٠', 'hi': '१०', 'zh': '十', 'ja': '十', 'ko': '십'},
    };

    if (specialNums.containsKey(val)) {
      return specialNums[val]![languageCode.toLowerCase()] ?? val.toString();
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(a.toString(), style: style), // For division we might have large numbers like 80
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '÷',
                  style: style.copyWith(color: Colors.blue, fontSize: fontSize * 0.8),
                ),
              ),
              Text(_getLocalizedDigit(b), style: style),
            ],
          ),
        ),
      ),
    );
  }
}
