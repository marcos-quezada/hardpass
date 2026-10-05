/*
 * hardpass-shutdown-btn.c - minimal replacement for triggerhappy (not
 * packaged on Alpine, confirmed via main/community/edge repos). Reads
 * raw input events from the gpio-shutdown overlay's input device and
 * calls `poweroff` on any key-press event, since this device only ever
 * emits one kind of event (KEY_POWER press) by design.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <linux/input.h>

int main(int argc, char **argv) {
	const char *dev = argc > 1 ? argv[1] : "/dev/input/event0";
	int fd = open(dev, O_RDONLY);
	if (fd < 0) {
		perror("open");
		return 1;
	}

	struct input_event ev;
	for (;;) {
		ssize_t n = read(fd, &ev, sizeof(ev));
		if (n != (ssize_t)sizeof(ev)) {
			continue;
		}
		if (ev.type == EV_KEY && ev.value == 1) {
			/* key press (value 1 = down, 0 = up, 2 = repeat) */
			system("poweroff");
		}
	}

	return 0;
}
