"""Check that every environment has the SSM parameters each service needs.

Exit codes: 0 = all present, 1 = something missing, 2 = bad input.
"""
import argparse
import json
import sys

import boto3


def expected_names(manifest, env):
    template = manifest["path_template"]
    return {
        template.format(env=env, service=service, name=name)
        for service, names in manifest["services"].items()
        for name in names
    }


def existing_names(ssm, env):
    names = set()
    paginator = ssm.get_paginator("get_parameters_by_path")
    for page in paginator.paginate(Path=f"/{env}/", Recursive=True):
        names.update(p["Name"] for p in page["Parameters"])
    return names


def audit(ssm, manifest, environments):
    """Return {env: sorted list of missing parameter names}."""
    return {
        env: sorted(expected_names(manifest, env) - existing_names(ssm, env))
        for env in environments
    }


def render_report(missing):
    lines = ["# SSM parameter audit", ""]
    for env, names in missing.items():
        status = "✅ complete" if not names else f"❌ {len(names)} missing"
        lines.append(f"## {env}: {status}")
        lines.extend(f"- `{n}`" for n in names)
        lines.append("")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--environments", required=True, help="Comma-separated, e.g. dev,uat,prod")
    parser.add_argument("--report", help="Write a Markdown report here")
    parser.add_argument("--region")
    args = parser.parse_args(argv)

    try:
        with open(args.manifest) as f:
            manifest = json.load(f)
    except (OSError, json.JSONDecodeError) as err:
        print(f"Cannot read manifest: {err}", file=sys.stderr)
        return 2

    environments = [e.strip() for e in args.environments.split(",") if e.strip()]
    ssm = boto3.client("ssm", region_name=args.region)
    missing = audit(ssm, manifest, environments)

    report = render_report(missing)
    print(report)
    if args.report:
        with open(args.report, "w") as f:
            f.write(report)

    return 1 if any(missing.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
