// bench_tailcall.java - self-recursive tail call, depth 2,000,000
//
// HotSpot does not eliminate tail calls, so at the default thread stack size
// this throws StackOverflowError instead of completing - that is the finding,
// not a harness bug.
public class bench_tailcall {
    static long tailSum(long n, long acc) {
        if (n == 0) return acc;
        return tailSum(n - 1, acc + n);
    }

    public static void main(String[] args) {
        final long n = 2_000_000;
        long t0 = System.nanoTime();
        long result = tailSum(n, 0);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + result);
        System.out.println("elapsed: " + ms + " ms");
    }
}
