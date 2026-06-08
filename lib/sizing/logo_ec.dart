import 'dart:math' as math;

/// Result of evaluating a centre logo against a matrix symbol's
/// error-correction budget.
class LogoBudget {
  /// Fraction of the symbol *area* the logo would cover.
  final double logoAreaFraction;

  /// The usable fraction = recoverable EC fraction × safety margin.
  final double budgetFraction;

  /// The largest logo side length (mm) that still fits the budget.
  final double maxSafeLogoMm;

  const LogoBudget({
    required this.logoAreaFraction,
    required this.budgetFraction,
    required this.maxSafeLogoMm,
  });

  /// True when the logo stays within the recoverable budget.
  bool get fits => logoAreaFraction <= budgetFraction;

  /// Headroom as a percentage of the budget (negative when over budget).
  double get headroomPercent =>
      budgetFraction == 0 ? 0 : (1 - logoAreaFraction / budgetFraction) * 100;
}

/// Models the trade-off between a centre logo (dead-space) and the
/// error-correction capacity of a matrix symbol (QR or Data Matrix).
///
/// A centred square logo destroys the modules it covers; those must be
/// recoverable by Reed–Solomon. We require the covered *area* fraction to stay
/// within [safetyMargin] (default 0.5) of the symbol's recoverable fraction so
/// scanners retain margin for print defects and damage.
class LogoEc {
  LogoEc._();

  static const double defaultSafetyMargin = 0.5;

  /// Evaluates a square logo of [logoSideMm] on a matrix symbol whose printed
  /// side measures [symbolSideMm], given the symbology's [recoverableFraction]
  /// (QR EC level, or Data Matrix fixed correction).
  static LogoBudget evaluate({
    required double logoSideMm,
    required double symbolSideMm,
    required double recoverableFraction,
    double safetyMargin = defaultSafetyMargin,
  }) {
    final sideFraction =
        symbolSideMm <= 0 ? 0.0 : (logoSideMm / symbolSideMm);
    final areaFraction = sideFraction * sideFraction;
    final budget = recoverableFraction * safetyMargin;
    final maxSafeMm = symbolSideMm * math.sqrt(budget);
    return LogoBudget(
      logoAreaFraction: areaFraction,
      budgetFraction: budget,
      maxSafeLogoMm: maxSafeMm,
    );
  }
}
