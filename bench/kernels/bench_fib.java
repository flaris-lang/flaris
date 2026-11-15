// bench_fib.java - recursive Fibonacci, n=38
public class bench_fib {
    static long fib(int n) {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }

    public static void main(String[] args) {
        final int n = 38;
        long t0 = System.nanoTime();
        long result = fib(n);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + result);
        System.out.println("elapsed: " + ms + " ms");
    }
}
