import 'package:bett_box/views/proxies/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares testing state and rejects overlapping group tests', () async {
    final coordinator = DelayTestCoordinator();

    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);

    var actionExecuted = false;
    final testFuture = coordinator.run('ProxyGroup', () async {
      actionExecuted = true;
      expect(coordinator.isTesting, isTrue);
      expect(coordinator.testingGroupName, 'ProxyGroup');
      expect(coordinator.isTestingGroup('ProxyGroup'), isTrue);
      expect(coordinator.isTestingGroup('OtherGroup'), isFalse);
    });

    final secondTestStarted = await coordinator.run('OtherGroup', () async {});
    expect(secondTestStarted, isFalse);

    await testFuture;

    expect(actionExecuted, isTrue);
    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);
  });

  test('clears testing state when a delay test fails', () async {
    final coordinator = DelayTestCoordinator();

    try {
      await coordinator.run('ProxyGroup', () async {
        throw Exception('network error');
      });
    } catch (_) {}

    expect(coordinator.isTesting, isFalse);
    expect(coordinator.testingGroupName, null);
  });

  test('notifies listeners when a group test starts and finishes', () async {
    final coordinator = DelayTestCoordinator();
    var notifications = 0;

    coordinator.addListener(() {
      notifications++;
    });

    await coordinator.run('ProxyGroup', () async {});

    expect(notifications, 2);
  });
}
