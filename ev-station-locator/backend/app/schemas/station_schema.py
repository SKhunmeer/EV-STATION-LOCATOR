from marshmallow import Schema, fields


class StationQuerySchema(Schema):
    provider = fields.String(load_default=None)
    city = fields.String(load_default=None)
    distance = fields.Float(load_default=20.0)
    min_power = fields.Float(load_default=0)
    max_price = fields.Float(load_default=100)
    availability = fields.String(load_default='available')
    search = fields.String(load_default='')


class ReservationSchema(Schema):
    station_id = fields.Integer(required=True)
    connector_id = fields.Integer(required=True)
    reservation_date = fields.String(required=True)
    start_time = fields.String(required=True)
    end_time = fields.String(required=True)
