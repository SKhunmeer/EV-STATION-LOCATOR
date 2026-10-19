from marshmallow import Schema, fields, validate


class UserRegistrationSchema(Schema):
    name = fields.String(required=True, validate=validate.Length(min=2, max=120))
    email = fields.Email(required=True)
    password = fields.String(required=True, load_only=True, validate=validate.Length(min=6))
    ev_model = fields.String(load_default='EV')
    battery_capacity_kwh = fields.Float(load_default=40.0)
    efficiency_km_per_kwh = fields.Float(load_default=6.0)


class UserLoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.String(required=True, load_only=True)


class UserUpdateSchema(Schema):
    name = fields.String(validate=validate.Length(min=2, max=120))
    ev_model = fields.String()
    battery_capacity_kwh = fields.Float()
    efficiency_km_per_kwh = fields.Float()
