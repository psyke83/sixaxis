#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <linux/input.h>

static int
test_grab(int fds)
{
    int rc;

    rc = ioctl(fds, EVIOCGRAB, (void*)1);

    if (rc == 0)
        ioctl(fds, EVIOCGRAB, (void*)0);

    return rc;
}

int
main(int argc, char *argv[])
{
    char buf[512];
    fd_set rfds;
    struct timeval timeout;
    int retval, fds;

    fds = open(argv[1], O_RDONLY|O_NONBLOCK);
    if (fds == -1)
        err(EXIT_FAILURE, "open `%s'", argv[1]);

    for (;;) {
        FD_ZERO(&rfds);
        FD_SET(fds, &rfds);

        while ((retval = read(fds, buf, sizeof(buf))) > 0)
            continue;
        if (retval == -1 && errno != EAGAIN)
            err(EXIT_FAILURE, "read");

        timeout.tv_sec = atoi(argv[2]);
        timeout.tv_usec = 0;

        retval = select(FD_SETSIZE, &rfds, NULL, NULL, &timeout);

        if (retval == -1) {
            close(fds);
            return EXIT_FAILURE;
        } else if (retval == 0 && test_grab(fds) == 0) {
            close(fds);
            return EXIT_SUCCESS;
        }
    }
}
