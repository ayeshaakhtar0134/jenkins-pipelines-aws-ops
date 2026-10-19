/**
 * Runs a block with temporary credentials for an IAM role, so jobs never use
 * long-lived keys for production accounts.
 * Usage: withAwsRole(roleArn: params.ROLE_ARN, region: 'us-east-1') { sh 'aws sts get-caller-identity' }
 * With no roleArn it uses the agent's own credentials (instance profile or ~/.aws).
 */
def call(Map args = [:], Closure body) {
    String region = args.region ?: 'us-east-1'
    if (!args.roleArn) {
        withEnv(["AWS_REGION=${region}", "AWS_DEFAULT_REGION=${region}"]) { body() }
        return
    }
    withAWS(role: args.roleArn, region: region, roleSessionName: "jenkins-${env.BUILD_TAG}".take(64)) {
        body()
    }
}
