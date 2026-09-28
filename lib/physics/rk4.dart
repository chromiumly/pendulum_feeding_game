/// Classic 4th-order Runge-Kutta step for an autonomous system y' = f(y).
///
/// The arithmetic order matches the TypeScript prototype (`RK4.ts`) so that
/// results are reproducible bit for bit on the same floating-point platform.
List<double> rk4Step(
  List<double> state,
  double dt,
  List<double> Function(List<double> state) derivatives,
) {
  final k1 = derivatives(state);
  final k2 = derivatives(_addScaled(state, k1, dt / 2));
  final k3 = derivatives(_addScaled(state, k2, dt / 2));
  final k4 = derivatives(_addScaled(state, k3, dt));
  return [
    for (var i = 0; i < state.length; i++)
      state[i] + (dt / 6) * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]),
  ];
}

/// state + scale * deriv
List<double> _addScaled(List<double> state, List<double> deriv, double scale) {
  return [for (var i = 0; i < state.length; i++) state[i] + deriv[i] * scale];
}
