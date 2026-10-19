// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:math' as math;

class RankingWeights {
  const RankingWeights({
    this.compatibility = .25,
    this.availability = .20,
    this.distance = .15,
    this.speed = .15,
    this.price = .10,
    this.rating = .10,
    this.battery = .05,
  });

  final double compatibility,
      availability,
      distance,
      speed,
      price,
      rating,
      battery;

  RankingWeights normalized() {
    final sum =
        compatibility +
        availability +
        distance +
        speed +
        price +
        rating +
        battery;
    if (sum <= 0) return const RankingWeights();
    return RankingWeights(
      compatibility: compatibility / sum,
      availability: availability / sum,
      distance: distance / sum,
      speed: speed / sum,
      price: price / sum,
      rating: rating / sum,
      battery: battery / sum,
    );
  }
}

class StationCandidate {
  const StationCandidate({
    required this.id,
    required this.distanceKm,
    required this.connectorTypes,
    required this.maxPowerKw,
    this.availableConnectors,
    this.totalConnectors,
    this.pricePerKwh,
    this.rating,
    this.reviewCount = 0,
    this.availabilityUpdatedAt,
  });

  final String id;
  final double distanceKm, maxPowerKw;
  final List<String> connectorTypes;
  final int? availableConnectors, totalConnectors;
  final double? pricePerKwh, rating;
  final int reviewCount;
  final DateTime? availabilityUpdatedAt;
}

class RankingContext {
  const RankingContext({
    required this.requiredConnectors,
    this.batteryPercent,
    this.batteryCapacityKwh,
    this.efficiencyKmPerKwh,
    this.reservePercent = 15,
    this.vehicleMaxPowerKw,
    this.weights = const RankingWeights(),
    this.now,
  });

  final List<String> requiredConnectors;
  final double? batteryPercent,
      batteryCapacityKwh,
      efficiencyKmPerKwh,
      vehicleMaxPowerKw;
  final double reservePercent;
  final RankingWeights weights;
  final DateTime? now;
}

class RankedStation {
  const RankedStation({
    required this.station,
    required this.score,
    required this.factors,
    required this.confidence,
  });
  final StationCandidate station;
  final double score;
  final Map<String, double?> factors;
  final double confidence;
}

class StationRanker {
  static String _connectorKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  static List<RankedStation> rank(
    Iterable<StationCandidate> stations,
    RankingContext context,
  ) {
    final weights = context.weights.normalized();
    final now = context.now ?? DateTime.now();
    final eligible = stations
        .where((station) {
          final compatible =
              context.requiredConnectors.isEmpty ||
              context.requiredConnectors.any(
                (required) => station.connectorTypes
                    .map(_connectorKey)
                    .contains(_connectorKey(required)),
              );
          if (!compatible) return false;
          if (context.batteryPercent != null &&
              context.batteryCapacityKwh != null &&
              context.efficiencyKmPerKwh != null) {
            final range =
                context.batteryCapacityKwh! *
                context.batteryPercent! /
                100 *
                context.efficiencyKmPerKwh!;
            if (station.distanceKm > range * (1 - context.reservePercent / 100))
              return false;
          }
          return true;
        })
        .map((station) {
          final availability = _availability(station, now);
          final factors = <String, double?>{
            'compatibility': 100,
            'availability': availability,
            'distance': _clamp(100 - station.distanceKm * 8),
            'speed': _clamp(
              (math.min(
                        station.maxPowerKw,
                        context.vehicleMaxPowerKw ?? station.maxPowerKw,
                      ) /
                      150) *
                  100,
            ),
            'price': station.pricePerKwh == null
                ? null
                : _clamp(100 - station.pricePerKwh! * 5),
            'rating': station.rating == null
                ? null
                : _confidenceAdjustedRating(
                    station.rating!,
                    station.reviewCount,
                  ),
            'battery': _batterySuitability(station, context),
          };
          final factorWeights = <String, double>{
            'compatibility': weights.compatibility,
            'availability': weights.availability,
            'distance': weights.distance,
            'speed': weights.speed,
            'price': weights.price,
            'rating': weights.rating,
            'battery': weights.battery,
          };
          var weighted = 0.0;
          var usedWeight = 0.0;
          for (final entry in factorWeights.entries) {
            final value = factors[entry.key];
            if (value != null) {
              weighted += value * entry.value;
              usedWeight += entry.value;
            }
          }
          return RankedStation(
            station: station,
            score: usedWeight == 0 ? 0 : weighted / usedWeight,
            factors: factors,
            confidence: usedWeight,
          );
        })
        .toList();
    eligible.sort(
      (a, b) => b.score.compareTo(a.score) == 0
          ? a.station.id.compareTo(b.station.id)
          : b.score.compareTo(a.score),
    );
    return eligible;
  }

  static double? _availability(StationCandidate station, DateTime now) {
    if (station.availableConnectors == null ||
        station.totalConnectors == null ||
        station.totalConnectors! <= 0)
      return null;
    if (station.availabilityUpdatedAt == null) return null;
    if (now.difference(station.availabilityUpdatedAt!).inMinutes > 30)
      return 35;
    return _clamp(
      station.availableConnectors! / station.totalConnectors! * 100,
    );
  }

  static double? _batterySuitability(
    StationCandidate station,
    RankingContext context,
  ) {
    if (context.batteryPercent == null ||
        context.batteryCapacityKwh == null ||
        context.efficiencyKmPerKwh == null)
      return null;
    final range =
        context.batteryCapacityKwh! *
        context.batteryPercent! /
        100 *
        context.efficiencyKmPerKwh!;
    return _clamp(100 - station.distanceKm / math.max(range, 1) * 100);
  }

  static double _confidenceAdjustedRating(double rating, int reviews) =>
      _clamp((rating * reviews + 3.5 * 10) / (reviews + 10) / 5 * 100);
  static double _clamp(double value) => value.clamp(0, 100).toDouble();
}
