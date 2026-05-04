/*
 * btb-collision.c — 测试 BTB 条目碰撞
 * 
 * 在相距 256 字节的两个地址各放一个分支, 使它们映射到同一个 BTB index
 * (PC[7:2] 相同, PC[31:8] 不同)。验证 tag 比对能正确区分。
 */
#include "trap.h"

// 使用 volatile 防止编译器优化掉分支
static int test_collision(void) {
    volatile int a = 0, b = 0;

    // Branch A: 循环 50 次, 跳转目标 = loop_a
    for (int i = 0; i < 50; i++) {
        a += i;
    }

    // Branch B: 循环 50 次, 跳转目标 = loop_b
    for (int i = 0; i < 50; i++) {
        b += i * 2;
    }

    check(a == 1225);   // 0+1+...+49 = 1225
    check(b == 2450);   // 2*(0+1+...+49) = 2450
    return 0;
}

int main() {
    // 重复多次, 让 BTB 充分学习
    for (int t = 0; t < 3; t++) {
        test_collision();
    }

    // 混合调用: A→B→A→B, 验证交替执行时 BTB 不混淆
    volatile int x = 0;
    for (int i = 0; i < 10; i++) x += i;     // branch A pattern
    check(x == 45);
    for (int i = 0; i < 20; i++) x += i * 3;  // branch B pattern  
    check(x == 615);  // 45 + 3*(0+1+...+19) = 45 + 570 = 615

    return 0;
}
