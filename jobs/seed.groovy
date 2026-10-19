// Job DSL: every pipelines/*.Jenkinsfile becomes a job under the "ops" folder.
// Adding a pipeline = adding a file to pipelines/ and an entry below.

def repo = System.getenv('OPS_REPO_URL') ?: 'https://github.com/ayeshaakhtar0134/jenkins-pipelines-aws-ops.git'

folder('ops') {
    description('AWS operations jobs, generated from code')
}

def pipelines = [
    'rds-snapshot-cleanup': 'Deletes manual RDS/Aurora snapshots older than N days (dry run by default)',
    'ssm-parameter-audit' : 'Checks every environment has the SSM parameters each service needs',
    'parallel-ecs-deploy' : 'Redeploys several ECS services in parallel and waits for them to be stable',
]

pipelines.each { name, desc ->
    pipelineJob("ops/${name}") {
        description(desc)
        logRotator { numToKeep(30) }
        definition {
            cpsScm {
                scm {
                    git {
                        remote { url(repo) }
                        branch('*/main')
                    }
                }
                scriptPath("pipelines/${name}.Jenkinsfile")
                lightweight(true)
            }
        }
    }
}
