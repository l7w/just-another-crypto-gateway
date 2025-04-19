import pytest
from payment_gateway import PaymentGateway

def test_validate_request():
    gateway = PaymentGateway()
    message = "PAY 0.1 0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
    is_valid, data = gateway.validate_request(message)
    assert is_valid
    assert data["command"] == "PAY"
    assert data["amount"] == 0.1
    assert data["recipient"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
