import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soutracking_flutter/data/mock_traccar_client.dart';
import 'package:soutracking_flutter/data/models.dart';
import 'package:soutracking_flutter/features/dashboard/executive_dashboard_screen.dart';
import 'package:soutracking_flutter/state/session_state.dart';

class _SessionFixture extends SessionController {
  _SessionFixture(Ref ref) : super(MockTraccarClient(), ref);
  void select(String email, {bool administrator = false}) {
    state = SessionState(
        status: SessionStatus.authenticated,
        email: email,
        authHeader: 'test-only',
        isAdministrator: administrator);
  }
}

void main() {
  test('Executive view fails closed and follows the selected user only',
      () async {
    SharedPreferences.setMockInitialValues({});
    final enabledUser = TraccarUser(
        id: 1,
        name: 'Gestor',
        email: 'gestor@example.invalid',
        administrator: false,
        readonly: false,
        disabled: false,
        attributes: {'souExecutiveView': true});
    final admin = TraccarUser(
        id: 2,
        name: 'Administrador',
        email: 'admin@example.invalid',
        administrator: true,
        readonly: false,
        disabled: false);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => _SessionFixture(ref)),
      usersProvider.overrideWith((ref) async => [enabledUser, admin])
    ]);
    addTearDown(container.dispose);
    final controller =
        container.read(sessionProvider.notifier) as _SessionFixture;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(executiveViewEnabledProvider), isFalse);
    await container.read(usersProvider.future);
    controller.select('admin@example.invalid', administrator: true);
    expect(container.read(executiveViewEnabledProvider), isFalse);
    controller.select(' Gestor@Example.invalid ');
    expect(container.read(executiveViewEnabledProvider), isTrue);
    controller.select('cliente@example.invalid');
    expect(container.read(executiveViewEnabledProvider), isFalse);
    container.invalidate(usersProvider);
    expect(container.read(executiveViewEnabledProvider), isFalse);
  });
}
