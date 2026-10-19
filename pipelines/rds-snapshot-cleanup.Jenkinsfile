@Library('ops-lib') _

pipeline {
    agent any
    options {
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
    }
    triggers {
        cron('H 2 * * *') // nightly dry run
    }
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'uat', 'prod'], description: 'Target environment')
        string(name: 'ROLE_ARN', defaultValue: '', description: 'IAM role to assume (empty = agent credentials)')
        string(name: 'REGION', defaultValue: 'us-east-1')
        string(name: 'RETENTION_DAYS', defaultValue: '14', description: 'Delete manual snapshots older than this')
        string(name: 'KEEP_LATEST', defaultValue: '3', description: 'Always keep this many newest snapshots per cluster')
        booleanParam(name: 'APPLY', defaultValue: false, description: 'Untick = dry run, only list what would be deleted')
    }
    stages {
        stage('Validate input') {
            steps {
                script {
                    if (!params.RETENTION_DAYS.isInteger() || params.RETENTION_DAYS.toInteger() < 1) {
                        error 'RETENTION_DAYS must be a positive whole number'
                    }
                    if (!params.KEEP_LATEST.isInteger()) {
                        error 'KEEP_LATEST must be a whole number'
                    }
                }
            }
        }
        stage('Find old snapshots') {
            steps {
                withAwsRole(roleArn: params.ROLE_ARN, region: params.REGION) {
                    sh """
                        scripts/cleanup-rds-snapshots.sh \
                          --retention-days ${params.RETENTION_DAYS} \
                          --keep-latest ${params.KEEP_LATEST} \
                          --output candidates.txt
                    """
                }
                archiveArtifacts artifacts: 'candidates.txt', allowEmptyArchive: true
            }
        }
        stage('Delete') {
            when { expression { params.APPLY } }
            steps {
                script {
                    int count = readFile('candidates.txt').readLines().findAll { it.trim() }.size()
                    approveIf(params.ENVIRONMENT == 'prod' && count > 0,
                              "Delete ${count} snapshots in ${params.ENVIRONMENT}?")
                }
                withAwsRole(roleArn: params.ROLE_ARN, region: params.REGION) {
                    sh 'scripts/cleanup-rds-snapshots.sh --delete-from candidates.txt'
                }
            }
        }
    }
    post {
        always {
            notifySlack(details: "Env: ${params.ENVIRONMENT}, apply: ${params.APPLY}")
        }
    }
}
