from flask import Blueprint, jsonify

from app.models import Provider

providers_bp = Blueprint('providers', __name__)


@providers_bp.get('/')
def list_providers():
    return jsonify([provider.to_dict() for provider in Provider.query.order_by(Provider.name).all()]), 200
