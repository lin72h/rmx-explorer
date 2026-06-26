/* op-150 notify churn probe — compiled replacement for the banned shell soak-driver.
 * Runs as a launchd child (bootstrap port inherited via plist). Loops
 * notify_register_check + notify_post + notify_check + notify_cancel for
 * SOAK_DURATION. Matches the original churn ops + ~1 iter/sec rate.
 * Links libnotify directly (metal, not shell). PASSIVE — no state change to
 * the runner/transport. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <notify.h>
#include <time.h>

#define NOTIFY_STATUS_OK 0

int main(void) {
    char *dur_env = getenv("SOAK_DURATION");
    int duration = dur_env ? atoi(dur_env) : 7200;
    time_t end = time(NULL) + duration;
    int iter = 0, fails = 0;

    printf("OP150_CHURN_START duration=%d\n", duration);
    fflush(stdout);

    while (time(NULL) < end) {
        iter++;
        int token = -1;
        uint32_t s;

        s = notify_register_check("test.op150.churn", &token);
        if (s != NOTIFY_STATUS_OK) { fails++; continue; }

        s = notify_post("test.op150.churn");
        if (s != NOTIFY_STATUS_OK) { fails++; notify_cancel(token); continue; }

        int check = 0;
        s = notify_check(token, &check);
        if (s != NOTIFY_STATUS_OK) { fails++; notify_cancel(token); continue; }

        s = notify_cancel(token);
        if (s != NOTIFY_STATUS_OK) { fails++; continue; }

        sleep(1); /* match original ~1 iter/sec rate */

        if (iter % 100 == 0) {
            printf("OP150_CHURN_HB iter=%d fails=%d\n", iter, fails);
            fflush(stdout);
        }
    }

    printf("OP150_CHURN_TERMINAL iter=%d fails=%d duration=%d\n", iter, fails, duration);
    fflush(stdout);
    return fails > 0 ? 1 : 0;
}
