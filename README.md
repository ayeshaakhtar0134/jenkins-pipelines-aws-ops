# jenkins-pipelines-aws-ops

![ci](https://github.com/ayeshaakhtar0134/jenkins-pipelines-aws-ops/actions/workflows/ci.yml/badge.svg)

**Jenkins as code for day-to-day AWS operations.** A Jenkins controller that configures itself from YAML, a shared library of reusable steps, and parameterised pipelines for real ops chores: snapshot cleanup, config audits and coordinated ECS redeploys. Everything is created from this repo. Nothing is clicked together in the UI.

## Architecture

```
  git push ──► GitHub ──► seed job (Job DSL, every 30 min)
                              │ creates/updates
                              ▼
            ┌──────────── folder: ops/ ────────────┐
            │ rds-snapshot-cleanup   (nightly)     │
            │ ssm-parameter-audit    (weekdays)    │──► Slack #ops-alerts
            │ parallel-ecs-deploy    (on demand)   │
            └──────────────────┬───────────────────┘
                               │ @Library('ops-lib')  vars/
                               ▼
              withAwsRole ──► STS AssumeRole ──► RDS · SSM · ECS
```

## What's inside

| Path | Purpose |
|------|---------|
| `jenkins/Dockerfile` | Jenkins LTS + AWS CLI + plugins, setup wizard disabled |
| `jenkins/casc.yaml` | **Configuration as Code**: users, permissions, shared library, Slack, seed job |
| `jobs/seed.groovy` | **Job DSL**: generates every pipeline job from code |
| `vars/withAwsRole.groovy` | Run steps with short-lived credentials from an assumed IAM role |
| `vars/approveIf.groovy` | Manual approval gate, only when it matters (e.g. prod + real run) |
| `vars/notifySlack.groovy` | Colour-coded Slack message with result, duration and log link |
| `pipelines/rds-snapshot-cleanup.Jenkinsfile` | Nightly dry run; deletes manual Aurora snapshots past retention, keeping the newest N per cluster |
| `pipelines/ssm-parameter-audit.Jenkinsfile` | Compares SSM Parameter Store across dev/uat/prod against a manifest; marks the build UNSTABLE if anything's missing |
| `pipelines/parallel-ecs-deploy.Jenkinsfile` | Force-redeploys several ECS services in parallel and waits until each is stable |
| `scripts/` | The logic lives in plain Bash/Python so it can be tested without Jenkins |
| `tests/` | Bash tests with fake snapshot data, pytest + moto for the SSM audit |

## Run it locally

```bash
cp .env.example .env          # set JENKINS_ADMIN_PASSWORD
docker compose up --build
# open http://localhost:8080, run "seed", then look in the "ops" folder
```

Jobs use your local `~/.aws` profile (mounted read-only), or pass `ROLE_ARN` to assume a role.

## Safety by design

- **Dry run by default.** `APPLY` must be ticked to delete anything, and the candidate list is archived with the build.
- **Prod needs a human.** Destructive prod runs pause for approval and time out after 30 minutes.
- **Never deletes everything.** The newest N snapshots per cluster are always kept, whatever their age.
- **No stored keys.** Jobs assume an IAM role per run via STS.
- **Testable.** CI runs shellcheck, the script tests, pytest and Groovy lint, and builds the Jenkins image.

## Run the tests

```bash
bash tests/test_cleanup_rds_snapshots.sh
pip install -r requirements-dev.txt && pytest -q tests
```

## Example: SSM audit report

```
# SSM parameter audit

## dev: ✅ complete

## prod: ❌ 2 missing
- `/prod/api/JWT_SECRET`
- `/prod/worker/QUEUE_URL`
```

## What I learned

- *Add 3–5 points from running these jobs yourself.*

## Roadmap

- [ ] Run agents as ECS Fargate tasks (amazon-ecs plugin)
- [ ] Cost report job (Cost Explorer → Slack weekly)
- [ ] Idle dev environment shutdown job
