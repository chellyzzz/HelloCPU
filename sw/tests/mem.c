#include "zxtest.h"

volatile int arr[64];

int main() {
    for (int i = 0; i < 64; i++) arr[i] = i + 100;
    for (int i = 0; i < 64; i++) check(arr[i] == i + 100, i + 1);
    puts_("mem test passed\n");
    pass();
    return 0;
}
