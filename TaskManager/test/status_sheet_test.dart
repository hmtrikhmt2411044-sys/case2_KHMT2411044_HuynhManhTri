import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task.dart';
import 'package:task_manager/widgets/status_sheet.dart';

void main() {
  group('showTaskStatusSheet widget tests', () {
    testWidgets('active task displays 3 workflow options and returns selected status', (tester) async {
      String? picked;
      final task = TaskModel(id: 't1', title: 'Hoàn thiện UI', status: 'todo');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  picked = await showTaskStatusSheet(ctx, task);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('CẬP NHẬT TIẾN ĐỘ'), findsOneWidget);
      expect(find.text('Hiện tại'), findsOneWidget);
      expect(find.text('Đang làm'), findsOneWidget);

      await tester.tap(find.text('Đang làm'));
      await tester.pumpAndSettle();

      expect(picked, equals('in_progress'));
    });

    testWidgets('completed task displays Reopen workflow instead of reset clutter', (tester) async {
      String? picked;
      final task = TaskModel(id: 't2', title: 'Nộp báo cáo', status: 'completed');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  picked = await showTaskStatusSheet(ctx, task);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ĐÃ HOÀN THÀNH'), findsOneWidget);
      expect(find.text('Công việc này đã hoàn tất'), findsOneWidget);
      expect(find.text('Mở lại công việc'), findsOneWidget);

      await tester.tap(find.text('Mở lại — Đang làm'));
      await tester.pumpAndSettle();

      expect(picked, equals('in_progress'));
    });
  });
}
