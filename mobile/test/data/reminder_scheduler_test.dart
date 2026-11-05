import 'package:caldav_free/core/models.dart';
import 'package:caldav_free/data/db/local_store.dart';
import 'package:caldav_free/data/reminders/notification_gateway.dart';
import 'package:caldav_free/data/reminders/reminder_plan.dart';
import 'package:caldav_free/data/reminders/reminder_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录调用，不碰平台通道。
class FakeGateway implements NotificationGateway {
  bool granted = true;
  bool? status = true;

  void Function(String? payload)? onTap;
  void Function(String? actionId, String? payload)? onAction;

  final List<ReminderPlanItem> scheduled = <ReminderPlanItem>[];
  final List<int> badges = <int>[];
  int cancelPendingCalls = 0;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? actionId, String? payload)? onAction,
  }) async {
    this.onTap = onTap;
    this.onAction = onAction;
  }

  @override
  Future<bool> requestPermissions() async => granted;

  @override
  Future<bool?> permissionStatus() async => status;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;

  @override
  Future<void> schedule(ReminderPlanItem item, {required bool exact}) async {
    scheduled.add(item);
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<bool> openSystemSettings() async => true;

  @override
  Future<void> setBadge(int count) async => badges.add(count);

  @override
  Future<void> cancelPending() async => cancelPendingCalls++;

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late LocalStore store;
  late FakeGateway gateway;
  late ReminderScheduler scheduler;

  TaskItem task({
    String id = 't1',
    DateTime? due,
    List<int> reminders = const <int>[],
    DateTime? completedAt,
  }) => TaskItem(
    id: id,
    listId: 'list-1',
    title: '任务 $id',
    dueAt: due,
    reminderOffsets: reminders,
    completedAt: completedAt,
    updatedAt: DateTime.utc(2026, 11, 5),
  );

  setUp(() {
    store = LocalStore.memory();
    gateway = FakeGateway();
    scheduler = ReminderScheduler(store: store, gateway: gateway);
  });

  tearDown(() async {
    await scheduler.stop();
    await store.dispose();
  });

  test('forwards the action callback to the gateway', () async {
    await scheduler.start(onTap: (_) {}, onAction: (_, _) {});
    expect(gateway.onAction, isNotNull);
    expect(gateway.onTap, isNotNull);
  });

  test('publishes the badge count for open tasks due today', () async {
    final now = DateTime.now();
    await store.saveTask(
      task(due: now.add(const Duration(hours: 1))),
      dirty: false,
    );
    await store.saveTask(
      task(id: 't2', due: now.add(const Duration(days: 3))),
      dirty: false,
    );

    await scheduler.start();
    expect(gateway.badges, isNotEmpty);
    expect(gateway.badges.last, 1);
  });

  test('snooze schedules a one-off reminder and keeps it across rebuilds', () async {
    final now = DateTime.now();
    await store.saveTask(
      task(due: now.add(const Duration(days: 2))),
      dirty: false,
    );

    await scheduler.start();
    gateway.scheduled.clear();

    final ok = await scheduler.snooze('task:t1', minutes: 10);
    expect(ok, true);
    expect(gateway.scheduled, hasLength(1));
    final snoozed = gateway.scheduled.single;
    expect(snoozed.payload, 'task:t1');
    expect(snoozed.body, '任务 t1');
    expect(
      snoozed.at.difference(now).inMinutes,
      inInclusiveRange(9, 11),
    );

    // 重建计划时必须把稍后提醒一起排上，否则会被 cancelPending 清掉。
    gateway.scheduled.clear();
    await scheduler.reschedule();
    expect(
      gateway.scheduled.where((item) => item.payload == 'task:t1'),
      hasLength(1),
    );
  });

  test('snooze ignores payloads that no longer resolve', () async {
    await scheduler.start();
    gateway.scheduled.clear();

    expect(await scheduler.snooze('task:missing'), false);
    expect(await scheduler.snooze('unknown:1'), false);
    expect(await scheduler.snooze(null), false);
    expect(gateway.scheduled, isEmpty);
  });
}
