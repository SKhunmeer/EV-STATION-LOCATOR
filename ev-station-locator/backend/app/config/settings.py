import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/evstation')
JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'change-me')
SECRET_KEY = os.getenv('SECRET_KEY', 'change-me')
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*').split(',')

# Legacy provider seed names are used only when ALLOW_DEMO_DATA=true.
SIMULATED_PROVIDERS = ['Tata Power', 'ChargeZone', 'Zeon', 'Statiq', 'Jio-bp']
