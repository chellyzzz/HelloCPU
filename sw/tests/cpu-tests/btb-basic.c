/*
 * btb_basic.c — 测试 BTB 基础分支预测
 * 验证: 简单循环中的分支正确跳转, BTB 命中后数据正确
 */
#include "trap.h"

int main() {
    volatile int sum = 0;
    volatile int i;

    // Test 1: 简单计数循环 (分支总是跳转, BTB 应命中)
    for (i = 0; i < 100; i++) {
        sum += i;
    }
    check(sum == 4950);  // 0+1+...+99 = 4950

    // Test 2: 嵌套循环 (外层循环分支不跳, 内层分支跳)
    sum = 0;
    for (i = 0; i < 10; i++) {
        for (int j = 0; j < 10; j++) {
            sum += 1;
        }
    }
    check(sum == 100);

    // Test 3: if-else (分支不跳)
    sum = 0;
    for (i = 0; i < 100; i++) {
        if (i & 1) {
            sum += 1;  // odd: taken
        } else {
            sum += 2;  // even: not-taken
        }
    }
    check(sum == 150);  // 50*1 + 50*2 = 150

    return 0;
}
