from app.algorithms.recommendation import recommended_stations


def station(identifier, distance, connector='CCS'):
    return {
        'id': identifier,
        'distance_km': distance,
        'charging_power_kw': 100,
        'connectors': [{'connector_type': connector}],
        'available_connectors': None,
        'total_connectors': 4,
        'price_per_kwh': None,
        'rating': None,
    }


def test_incompatible_station_is_excluded():
    result = recommended_stations([station('good', 5), station('wrong', 1, 'CHAdeMO')], preferences={'required_connectors': ['CCS']})
    assert [item['id'] for item in result] == ['good']


def test_unreachable_station_is_excluded():
    result = recommended_stations([station('near', 10), station('far', 100)], preferences={'estimated_range_km': 50, 'reserve_percent': 15})
    assert [item['id'] for item in result] == ['near']


def test_missing_values_do_not_receive_ideal_scores():
    result = recommended_stations([station('unknown', 5)])
    assert result[0]['ranking_score'] < 100
