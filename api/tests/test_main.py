from unittest.mock import Mock

from fastapi.testclient import TestClient

from api import main


client = TestClient(main.app)


def test_create_job_enqueues_and_sets_status(monkeypatch):
    fake_redis = Mock()
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.post("/jobs")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "queued"
    fake_redis.hset.assert_called_once_with(f"job:{payload['job_id']}", "status", "queued")
    fake_redis.lpush.assert_called_once_with(main.QUEUE_NAME, payload["job_id"])


def test_get_job_returns_existing_status(monkeypatch):
    fake_redis = Mock()
    fake_redis.hget.return_value = "completed"
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.get("/jobs/demo-job")

    assert response.status_code == 200
    assert response.json() == {"job_id": "demo-job", "status": "completed"}
    fake_redis.hget.assert_called_once_with("job:demo-job", "status")


def test_get_job_returns_404_for_missing_job(monkeypatch):
    fake_redis = Mock()
    fake_redis.hget.return_value = None
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.get("/jobs/missing-job")

    assert response.status_code == 404
    assert response.json() == {"detail": "job not found"}


def test_healthcheck_returns_503_when_redis_is_unavailable(monkeypatch):
    fake_redis = Mock()
    fake_redis.ping.side_effect = main.redis.RedisError("boom")
    monkeypatch.setattr(main, "r", fake_redis)

    response = client.get("/health")

    assert response.status_code == 503
    assert "redis unavailable" in response.json()["detail"]
