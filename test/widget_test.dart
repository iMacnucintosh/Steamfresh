import 'package:flutter_test/flutter_test.dart';
import 'package:steamfresh/main.dart';

void main() {
  testWidgets('SteamFresh muestra la pantalla de login', (tester) async {
    await tester.pumpWidget(
      const SteamFreshApp(),
    );

    expect(find.text('SteamFresh'), findsOneWidget);
    expect(find.text('Iniciar sesión con Steam'), findsOneWidget);
  });
}
