import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/domain/entities/anlas_estimate.dart';

void main() {
  test('Opus 在标准画幅与 28 步内免除一张样本', () {
    final estimate = estimateAnlas(
      width: 832,
      height: 1216,
      steps: 28,
      sampleCount: 1,
      isOpus: true,
    );

    expect(estimate.billableSamples, 0);
    expect(estimate.total, 0);
    expect(estimate.isFree, isTrue);
  });

  test('超过步数上限后 Opus 不再免费', () {
    final estimate = estimateAnlas(
      width: 832,
      height: 1216,
      steps: 32,
      sampleCount: 1,
      isOpus: true,
    );

    expect(estimate.billableSamples, 1);
    expect(estimate.total, greaterThan(0));
  });

  test('大图超出免费像素上限，每张样本都计费', () {
    final estimate = estimateAnlas(
      width: 1536,
      height: 1024,
      steps: 28,
      sampleCount: 2,
      isOpus: true,
    );

    expect(estimate.billableSamples, 2);
    expect(estimate.total, estimate.perImage * 2);
  });

  test('重绘强度按比例降低单张成本，但不低于 2 Anlas', () {
    final full = estimateAnlas(
      width: 1024,
      height: 1024,
      steps: 28,
      sampleCount: 1,
      isOpus: false,
    );
    final partial = estimateAnlas(
      width: 1024,
      height: 1024,
      steps: 28,
      sampleCount: 1,
      isOpus: false,
      strength: 0.5,
      hasSourceImage: true,
      hasMask: true,
    );

    expect(partial.perImage, lessThan(full.perImage));
    expect(partial.perImage, greaterThanOrEqualTo(2));
  });

  test('角色与 Vibe 参考的附加费用即使 Opus 免费也会计入', () {
    final estimate = estimateAnlas(
      width: 832,
      height: 1216,
      steps: 28,
      sampleCount: 1,
      isOpus: true,
      characterReferenceCount: 1,
      vibeReferenceCount: 1,
    );

    expect(estimate.billableSamples, 0);
    expect(estimate.referenceSurcharge, 10);
    expect(estimate.total, 10);
  });
}
