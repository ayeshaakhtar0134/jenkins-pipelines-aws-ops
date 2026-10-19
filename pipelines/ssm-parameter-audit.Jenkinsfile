@Library('ops-lib') _

pipeline {
    agent any
    options {
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
    }
    triggers {
        cron('H 7 * * 1-5') // weekday mornings
    }
    parameters {
        string(name: 'ROLE_ARN', defaultValue: '', description: 'IAM role to assume (empty = agent credentials)')
        string(name: 'REGION', defaultValue: 'us-east-1')
        string(name: 'ENVIRONMENTS', defaultValue: 'dev,uat,prod', description: 'Comma-separated environments to compare')
    }
    stages {
        stage('Audit') {
            steps {
                withAwsRole(roleArn: params.ROLE_ARN, region: params.REGION) {
                    // Exit code 1 = parameters missing; mark UNSTABLE instead of failing the whole build
                    script {
                        int rc = sh(returnStatus: true, script: """
                            python3 scripts/ssm_param_audit.py \
                              --manifest scripts/required-parameters.json \
                              --environments ${params.ENVIRONMENTS} \
                              --report audit-report.md
                        """)
                        if (rc == 1) {
                            unstable('Some environments are missing parameters, see audit-report.md')
                        } else if (rc != 0) {
                            error("Audit script crashed (exit ${rc})")
                        }
                    }
                }
                archiveArtifacts artifacts: 'audit-report.md', allowEmptyArchive: true
            }
        }
    }
    post {
        always {
            notifySlack(channel: '#ops-audit')
        }
    }
}
