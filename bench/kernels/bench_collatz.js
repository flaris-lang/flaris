// bench_collatz.js - total Collatz steps for n=1..1,000,000 (qjs)
function collatzSteps(n) {
    let steps = 0;
    while (n !== 1) {
        n = (n % 2) ? n * 3 + 1 : n / 2;
        steps++;
    }
    return steps;
}

const N = 1000000;
const t0 = Date.now();
let total = 0;
for (let i = 1; i <= N; i++)
    total += collatzSteps(i);
const elapsed = Date.now() - t0;
print("result: " + total);
print("elapsed: " + elapsed + " ms");
