import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:navigators/src/app.dart';

void main() {
  testWidgets('NavigatorsApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: NavigatorsApp()),
    );

    // App should render the login screen when unauthenticated.
    await tester.pumpAndSettle();
    expect(find.byType(NavigatorsApp), findsOneWidget);
  });
}
