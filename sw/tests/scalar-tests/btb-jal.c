/*
 * btb-jal.c — 测试 BTB 分支 + JAL 函数调用交互
 * 验证: 函数调用中的分支预测不被 JAL 的 pc_update 破坏
 */
#include "trap.h"

static int inner_sum(int n) {
    volatile int s = 0;
    for (int i = 0; i < n; i++) {
        s += i;
    }
    return s;
}

static int call_twice(int x) {
    volatile int a = inner_sum(x);
    volatile int b = inner_sum(x + 10);
    return a + b;
}

static int deep_chain(int depth, int acc) {
    if (depth == 0) return acc;
    return deep_chain(depth - 1, acc + depth);
}

int main() {
    // Test 1: 函数内部循环 + 多次调用
    volatile int r1 = call_twice(5);
    check(r1 == 115);  // inner_sum(5)=10 + inner_sum(15)=105 = 115

    // Test 2: 递归函数
    volatile int r2 = deep_chain(10, 0);
    check(r2 == 55);  // 10+9+...+1 = 55

    // Test 3: 循环中多次调用函数 (JAL + branch 交替)
    volatile int total = 0;
    for (int i = 1; i <= 10; i++) {
        total += inner_sum(i);
    }
    check(total == 165);  // sum_{i=1..10} sum_{j=0..i-1} j = 165

    return 0;
}
