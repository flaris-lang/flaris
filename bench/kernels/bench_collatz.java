// bench_collatz.java - total Collatz steps for n=1..1,000,000
public class bench_collatz {
    static long collatzSteps(long n) {
        long steps = 0;
        while (n != 1) {
            n = (n & 1) != 0 ? n * 3 + 1 : n >> 1;
            steps++;
        }
        return steps;
    }

    public static void main(String[] args) {
        final long n = 1_000_000;
        long t0 = System.nanoTime();
        long total = 0;
        for (long i = 1; i <= n; i++)
            total += collatzSteps(i);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + total);
        System.out.println("elapsed: " + ms + " ms");
    }
}
