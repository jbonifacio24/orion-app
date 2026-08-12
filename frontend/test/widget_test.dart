import 'package:flutter_test/flutter_test.dart';

import 'package:motohub/main.dart';

void main() {
  testWidgets('renders the MotoHub foundation screen', (tester) async {
    await tester.pumpWidget(const MotoHubApp());

    expect(find.text('MotoHub'), findsOneWidget);
    expect(find.text('Bienvenido a MotoHub'), findsOneWidget);
  });
}
