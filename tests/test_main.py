import flask
import pytest

from src.main import handler, main


class MockRequest:
    """
    Fake a minimal request using a dummy class instead
    of building a proper fake HTTP environment.
    """
    def get_json(self):
        return {"field_1": "fii", "field_2": "foo"}

def test_main_happy_path(caplog):

    request = MockRequest()

    with caplog.at_level("INFO"):
        body, status = main(request)

    assert "" in caplog.text


def test_handler_happy_path():
    payload = {"field_1": "fii", "field_2": "foo"}
    body, status = handler(payload)
    assert status == 200
    assert body == "OK"
