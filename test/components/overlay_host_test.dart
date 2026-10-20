import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/overlay_host.dart';

void main() {
  testWidgets('hosted text field keeps deletions and reports changes', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Column(
          children: [
            SizedBox(
              height: 48,
              child: OverlayHost(
                child: Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: controller,
                    onChanged: changes.add,
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
        home: const Scaffold(body: Text('body')),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final input = tester.testTextInput;
    for (final value in [
      const TextEditingValue(
        text: 'asdf',
        selection: TextSelection.collapsed(offset: 4),
      ),
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
      const TextEditingValue(
        text: 'gh',
        selection: TextSelection.collapsed(offset: 2),
      ),
    ]) {
      input.updateEditingValue(value);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(controller.text, 'gh');
    expect(changes, ['asdf', '', 'gh']);
  });
}
