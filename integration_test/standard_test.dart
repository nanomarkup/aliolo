import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aliolo/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('basic app launch test', (WidgetTester tester) async {
    await tester.pumpWidget(const AlioloApp());
    await tester.pumpAndSettle();
    
    // Check if the app is rendered
    expect(find.byType(AlioloApp), findsOneWidget);
  });
}
