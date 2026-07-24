import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Load a tiny test-only counter widget instead of your real app.
    await tester.pumpWidget(const MaterialApp(
      home: _TestCounterWidget(),
    ));

    // Start at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap + button.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Now should be 1.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}

class _TestCounterWidget extends StatefulWidget {
  const _TestCounterWidget({Key? key}) : super(key: key);

  @override
  State<_TestCounterWidget> createState() => _TestCounterWidgetState();
}

class _TestCounterWidgetState extends State<_TestCounterWidget> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$_count',
          style: const TextStyle(fontSize: 40),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
