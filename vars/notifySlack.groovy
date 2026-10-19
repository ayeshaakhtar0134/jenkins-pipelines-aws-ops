/**
 * Posts the build result to Slack with a link to the console log.
 * Usage (in post { always { ... } }): notifySlack(channel: '#ops-alerts')
 * Skips quietly if the Slack token isn't configured, so local runs still pass.
 */
def call(Map args = [:]) {
    String channel = args.channel ?: '#ops-alerts'
    String result = currentBuild.currentResult
    Map colors = [SUCCESS: 'good', UNSTABLE: 'warning', FAILURE: 'danger', ABORTED: '#808080']
    String duration = currentBuild.durationString.replace(' and counting', '')
    String message = "*${result}*: `${env.JOB_NAME}` #${env.BUILD_NUMBER} (${duration})\n" +
        (args.details ? "${args.details}\n" : '') +
        "<${env.BUILD_URL}console|Open console log>"

    try {
        slackSend(channel: channel, color: colors.get(result, '#808080'), message: message)
    } catch (err) {
        echo "Slack notification skipped: ${err.message}"
    }
}
