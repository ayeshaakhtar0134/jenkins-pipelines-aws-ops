import json
import os
import sys

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import ssm_param_audit  # noqa: E402

MANIFEST = {
    "path_template": "/{env}/{service}/{name}",
    "services": {"api": ["DB_URL", "JWT_SECRET"], "worker": ["QUEUE_URL"]},
}


@pytest.fixture
def ssm():
    os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
    with mock_aws():
        client = boto3.client("ssm", region_name="us-east-1")
        for name in ["/dev/api/DB_URL", "/dev/api/JWT_SECRET", "/dev/worker/QUEUE_URL", "/prod/api/DB_URL"]:
            client.put_parameter(Name=name, Value="x", Type="SecureString")
        yield client


def test_reports_missing_per_environment(ssm):
    missing = ssm_param_audit.audit(ssm, MANIFEST, ["dev", "prod"])
    assert missing["dev"] == []
    assert missing["prod"] == ["/prod/api/JWT_SECRET", "/prod/worker/QUEUE_URL"]


def test_exit_code_and_report(ssm, tmp_path):
    manifest = tmp_path / "m.json"
    manifest.write_text(json.dumps(MANIFEST))
    report = tmp_path / "r.md"
    rc = ssm_param_audit.main(
        ["--manifest", str(manifest), "--environments", "dev,prod", "--report", str(report), "--region", "us-east-1"]
    )
    assert rc == 1
    text = report.read_text()
    assert "dev: ✅ complete" in text
    assert "prod: ❌ 2 missing" in text


def test_bad_manifest_returns_2(tmp_path):
    assert ssm_param_audit.main(["--manifest", str(tmp_path / "nope.json"), "--environments", "dev"]) == 2
