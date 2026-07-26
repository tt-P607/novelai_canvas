import 'dart:math' as math;

/// Opus accounts generate one free sample below this pixel count and step
/// count; anything larger is billed for every sample.
const _opusFreeArea = 1048576;
const _opusFreeSteps = 28;

/// Estimated Anlas cost of a single generation request.
///
/// Mirrors the formula the official frontend uses. Billing is authoritative on
/// the server, so this is a preview only.
class AnlasEstimate {
  const AnlasEstimate({
    required this.total,
    required this.perImage,
    required this.billableSamples,
    required this.referenceSurcharge,
  });

  final int total;
  final int perImage;
  final int billableSamples;

  /// Character and vibe reference extras, billed even when Opus covers the
  /// base generation.
  final int referenceSurcharge;

  bool get isFree => total == 0;
}

/// Computes the Anlas preview for the current creation settings.
AnlasEstimate estimateAnlas({
  required int width,
  required int height,
  required int steps,
  required int sampleCount,
  required bool isOpus,
  double strength = 1.0,
  bool hasSourceImage = false,
  bool hasMask = false,
  int characterReferenceCount = 0,
  int vibeReferenceCount = 0,
}) {
  final area = width * height;
  final base =
      (2.951823174884865e-6 * area + 5.753298233447344e-7 * area * steps)
          .ceil();

  // Image-driven modes only denoise part of the latent, so the cost scales
  // with the requested strength.
  final strengthFactor = hasMask || hasSourceImage ? strength : 1.0;
  final perImage = math.max((base * strengthFactor).ceil(), 2);

  final qualifiesForOpus =
      isOpus && area <= _opusFreeArea && steps <= _opusFreeSteps;
  final billableSamples = qualifiesForOpus
      ? math.max(sampleCount - 1, 0)
      : sampleCount;

  final referenceSurcharge =
      (5 * characterReferenceCount + 5 * vibeReferenceCount) * sampleCount;

  return AnlasEstimate(
    total: perImage * billableSamples + referenceSurcharge,
    perImage: perImage,
    billableSamples: billableSamples,
    referenceSurcharge: referenceSurcharge,
  );
}
