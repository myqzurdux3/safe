import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('arrière-plan ne verrouille plus tout de suite', () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(minutes: 5),
    );
    session.handleLifecycle(AppLifecycleState.paused);
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  test('le sélecteur d\'applications ne verrouille pas', () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(minutes: 5),
    );
    session.handleLifecycle(AppLifecycleState.inactive);
    session.handleLifecycle(AppLifecycleState.hidden);
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  test('retour avant le délai: la session est toujours ouverte', () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 400),
    );
    session.handleLifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    session.handleLifecycle(AppLifecycleState.resumed);
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  test('le temps en arrière-plan compte: retour après le délai = verrouillé',
      () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 150),
    );
    session.handleLifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    session.handleLifecycle(AppLifecycleState.resumed);
    expect(session.isUnlocked, isFalse);
  });

  test('le retour au premier plan ne compte pas comme une activité', () async {
    // Sinon revenir sur l'app remettrait le compteur à zéro indéfiniment.
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 300),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    session.handleLifecycle(AppLifecycleState.paused);
    session.handleLifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(session.isUnlocked, isFalse);
  });

  test('après un aller-retour, une vraie activité repousse le verrou',
      () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 300),
    );
    session.handleLifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    session.handleLifecycle(AppLifecycleState.resumed);
    session.touch();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(session.isUnlocked, isTrue);
    session.lock();
  });

  test('verrouillage pendant l\'arrière-plan, sans retour au premier plan',
      () async {
    // La minuterie doit continuer de tourner: l'app ne doit pas rester
    // déverrouillée indéfiniment tant que l'utilisateur ne revient pas.
    final session = await makeUnlockedSession(
      autoLock: const Duration(milliseconds: 150),
    );
    session.handleLifecycle(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(session.isUnlocked, isFalse);
  });

  test('detached verrouille: le processus s\'arrête', () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(minutes: 5),
    );
    session.handleLifecycle(AppLifecycleState.detached);
    expect(session.isUnlocked, isFalse);
  });

  test('changer le délai repart de la dernière activité', () async {
    final session = await makeUnlockedSession(
      autoLock: const Duration(minutes: 5),
    );
    session.autoLockDelay = const Duration(milliseconds: 150);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(session.isUnlocked, isFalse);
  });
}
