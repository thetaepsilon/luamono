#include <unistd.h>
#include <stdint.h>
#include <stdbool.h>

struct read_raw {
	char enable;
	char space;
	char hex[16];
	char newline;
};

struct entry {
	bool enable;
	uint64_t samples;
};

inline unsigned short decode(struct read_raw* in) {
	char _enable = in->enable;
	bool enable = false;
	if (_enable == '1') {
		enable = true;
	} else {
		if (_enable != '0') return 1;
	}

	if (in->space != ' ') return 2;
	if (in->newline != '\n') return 3;

	
}


