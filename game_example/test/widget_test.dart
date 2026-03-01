import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders cupertino app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CupertinoApp(home: SizedBox.shrink()));
    expect(find.byType(CupertinoApp), findsOneWidget);
  });
}
