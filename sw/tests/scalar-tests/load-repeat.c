#include "zxtest.h"

volatile unsigned memword = 0x12345678;
volatile unsigned sink = 0x12345678;

int main() {
    for (int i = 0; i < 32; ++i) {
        sink = memword;
    }

    check(sink == 0x12345678, 1);
    pass();
    return 0;
}
