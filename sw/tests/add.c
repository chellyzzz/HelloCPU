#include "zxtest.h"

int main() {
    int a = 1, b = 2;
    check(a + b == 3, 1);
    check(a - b == -1, 2);
    check(b * 3 == 6, 3);
    pass();
    return 0;
}
