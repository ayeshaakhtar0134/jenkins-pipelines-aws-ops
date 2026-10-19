@Library('ops-lib') _

// Forces a new deployment of several ECS services at once (e.g. after a
// shared secret or base image changed) and waits until all are stable.

pipeline {
    agent any
    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 45, unit: 'MINUTES')
    }
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'uat', 'prod'])
        string(name: 'ROLE_ARN', defaultValue: '', description: 'IAM role to assume (empty = agent credentials)')
        string(name: 'REGION', defaultValue: 'us-east-1')
        string(name: 'CLUSTER', defaultValue: 'ecs-platform-dev')
        string(name: 'SERVICES', defaultValue: 'api,worker', description: 'Comma-separated ECS service names')
    }
    stages {
        stage('Approve prod') {
            steps {
                approveIf(params.ENVIRONMENT == 'prod', "Redeploy ${params.SERVICES} in prod?")
            }
        }
        stage('Deploy') {
            steps {
                script {
                    List<String> services = params.SERVICES.split(',')*.trim().findAll { it }
                    Map branches = services.collectEntries { svc ->
                        [(svc): {
                            withAwsRole(roleArn: params.ROLE_ARN, region: params.REGION) {
                                sh """
                                    aws ecs update-service --cluster ${params.CLUSTER} --service ${svc} \
                                      --force-new-deployment --query 'service.serviceName' --output text
                                    aws ecs wait services-stable --cluster ${params.CLUSTER} --services ${svc}
                                    echo "${svc} is stable"
                                """
                            }
                        }]
                    }
                    branches.failFast = false
                    parallel branches
                }
            }
        }
    }
    post {
        always {
            notifySlack(details: "Cluster ${params.CLUSTER}: ${params.SERVICES}")
        }
    }
}
