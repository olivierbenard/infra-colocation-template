"""
Simple module containing the entry point for the pilot CF method.
"""

import flask

from src import logger


def main(request: flask.Request) -> tuple[str, int]:
    """
    Thin HTTP/Flask adapter.
    """
    payload = request.get_json() or {}
    logger.info("Received payload: %s", payload)
    return handler(payload)


def handler(payload: dict) -> tuple[str, int]:
    """
    Framework-agnostic business logic.
    """
    env = payload.get("env")
    print(env)
    return "OK", 200
