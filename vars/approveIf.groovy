/**
 * Pauses for a human "Proceed" click before a destructive step, but only when
 * the condition is true (e.g. a real run against prod). Times out and aborts.
 * Usage: approveIf(params.APPLY && params.ENVIRONMENT == 'prod', 'Delete 12 snapshots in prod?')
 */
def call(boolean condition, String question, int timeoutMinutes = 30) {
    if (!condition) {
        return
    }
    timeout(time: timeoutMinutes, unit: 'MINUTES') {
        input(message: question, ok: 'Proceed')
    }
}
