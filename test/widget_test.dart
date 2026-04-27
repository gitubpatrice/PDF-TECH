import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tech/main.dart';

void main() {
  testWidgets('App démarre sans erreur', (WidgetTester tester) async {
    await tester.pumpWidget(const PdfTechApp());
    expect(find.text('PDF Tech'), findsOneWidget);
  });
}
