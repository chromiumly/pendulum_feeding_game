// Compares the Dart double-pendulum against golden data produced by the
// TypeScript prototype (see tool/ts_reference/generate_golden.mjs).
// Regenerate the fixture with: node tool/ts_reference/generate_golden.mjs
//
// The fixture is read with dart:io, so this test runs on the VM only.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pendulum_feeding_game/math/vec2.dart';
import 'package:pendulum_feeding_game/physics/double_pendulum.dart';

List<double> _doubles(Object? json) => [
  for (final v in json! as List) (v as num).toDouble(),
];

void main() {
  final golden = jsonDecode(
    File('test/fixtures/pendulum_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  const pendulum = DoublePendulum();

  test('parameters and initial condition match the prototype', () {
    final params = golden['params'] as Map<String, dynamic>;
    expect(pendulum.params.upperMass, params['upperMass']);
    expect(pendulum.params.lowerMass, params['lowerMass']);
    expect(pendulum.params.upperLength, params['upperLength']);
    expect(pendulum.params.lowerLength, params['lowerLength']);
    expect(pendulum.params.gravityAcceleration, params['gravityAcceleration']);

    final initial = golden['initial'] as Map<String, dynamic>;
    expect(PendulumState.initial.toList(), _doubles(initial['state']));
  });

  test('derivatives match the prototype', () {
    for (final entry in golden['derivatives'] as List) {
      final e = entry as Map<String, dynamic>;
      final actual = pendulum.derivatives(_doubles(e['state']));
      final expected = _doubles(e['derivative']);
      for (var i = 0; i < 4; i++) {
        expect(
          actual[i],
          closeTo(expected[i], 1e-15 * (1 + expected[i].abs())),
          reason: 'state=${e['state']} index=$i',
        );
      }
    }
  });

  for (final name in ['fixed60', 'variable']) {
    test('RK4 trajectory "$name" matches the prototype', () {
      final frames =
          (golden['trajectories'] as Map<String, dynamic>)[name] as List;
      final origin = _doubles((golden['initial'] as Map)['origin']);
      final originVec = Vec2(origin[0], origin[1]);

      var state = PendulumState.initial;
      var maxStateError = 0.0;
      var maxPositionError = 0.0;
      var bitExactSteps = 0;

      for (var step = 0; step < frames.length; step++) {
        final frame = frames[step] as Map<String, dynamic>;
        if (step > 0) {
          state = pendulum.step(state, (frame['dt'] as num).toDouble());
        }
        final expectedState = _doubles(frame['state']);
        final actualState = state.toList();
        var exact = true;
        for (var i = 0; i < 4; i++) {
          final err = (actualState[i] - expectedState[i]).abs();
          if (err != 0) exact = false;
          if (err > maxStateError) maxStateError = err;
        }
        if (exact && bitExactSteps == step) bitExactSteps++;

        final positions = pendulum.positions(state, originVec);
        final upper = _doubles(frame['upper']);
        final lower = _doubles(frame['lower']);
        for (final err in [
          (positions.upper.x - upper[0]).abs(),
          (positions.upper.y - upper[1]).abs(),
          (positions.lower.x - lower[0]).abs(),
          (positions.lower.y - lower[1]).abs(),
        ]) {
          if (err > maxPositionError) maxPositionError = err;
        }
      }

      // ignore: avoid_print
      print(
        '[$name] steps=${frames.length - 1} '
        'bitExactPrefix=$bitExactSteps '
        'maxStateError=$maxStateError maxPositionError=$maxPositionError',
      );

      // Dart VM and V8 may differ in the last ulp of sin/cos, so allow a tiny
      // tolerance; any modelling or ordering mistake shows up far above this.
      expect(maxStateError, lessThan(1e-9));
      expect(maxPositionError, lessThan(1e-7));
    });
  }
}
