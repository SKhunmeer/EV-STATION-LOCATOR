import 'package:flutter_test/flutter_test.dart';
import 'package:ev_station_locator/core/ranking.dart';

void main() {
  final context = RankingContext(
    requiredConnectors: const ['CCS'],
    batteryPercent: 80,
    batteryCapacityKwh: 60,
    efficiencyKmPerKwh: 5,
    now: DateTime(2026, 1, 1, 12),
  );

  test('excludes incompatible and unreachable stations', () {
    final result = StationRanker.rank([
      const StationCandidate(
        id: 'compatible',
        distanceKm: 10,
        connectorTypes: ['CCS'],
        maxPowerKw: 120,
      ),
      const StationCandidate(
        id: 'wrong-plug',
        distanceKm: 1,
        connectorTypes: ['CHAdeMO'],
        maxPowerKw: 250,
      ),
      const StationCandidate(
        id: 'too-far',
        distanceKm: 300,
        connectorTypes: ['CCS'],
        maxPowerKw: 250,
      ),
    ], context);
    expect(result.map((item) => item.station.id), ['compatible']);
  });

  test(
    'handles missing availability and price without treating them as ideal',
    () {
      final result = StationRanker.rank(
        [
          const StationCandidate(
            id: 'missing',
            distanceKm: 5,
            connectorTypes: ['CCS'],
            maxPowerKw: 100,
          ),
        ],
        RankingContext(
          requiredConnectors: const ['CCS'],
          now: DateTime(2026, 1, 1, 12),
        ),
      );
      expect(result.single.factors['availability'], isNull);
      expect(result.single.factors['price'], isNull);
      expect(result.single.factors['battery'], isNull);
      expect(result.single.confidence, lessThan(1));
    },
  );

  test('normalizes connector labels before compatibility checks', () {
    final result = StationRanker.rank([
      const StationCandidate(
        id: 'ccs',
        distanceKm: 2,
        connectorTypes: ['CCS (Type 2)'],
        maxPowerKw: 100,
      ),
    ], context);
    expect(result.map((item) => item.station.id), ['ccs']);
  });

  test('stale availability is explicitly discounted', () {
    final result = StationRanker.rank([
      StationCandidate(
        id: 'stale',
        distanceKm: 5,
        connectorTypes: const ['CCS'],
        maxPowerKw: 100,
        availableConnectors: 4,
        totalConnectors: 4,
        availabilityUpdatedAt: DateTime(2025, 12, 31),
      ),
    ], context);
    expect(result.single.factors['availability'], 35);
  });

  test('weights normalize and ranking is deterministic on ties', () {
    final result = StationRanker.rank([
      const StationCandidate(
        id: 'b',
        distanceKm: 1,
        connectorTypes: ['CCS'],
        maxPowerKw: 100,
      ),
      const StationCandidate(
        id: 'a',
        distanceKm: 1,
        connectorTypes: ['CCS'],
        maxPowerKw: 100,
      ),
    ], context);
    expect(result.map((item) => item.station.id), ['a', 'b']);
    final weights = const RankingWeights().normalized();
    expect(
      weights.compatibility +
          weights.availability +
          weights.distance +
          weights.speed +
          weights.price +
          weights.rating +
          weights.battery,
      closeTo(1, 0.000001),
    );
  });
}
