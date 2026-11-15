// bench_sieve.java - Sieve of Eratosthenes, N=10,000,000
import java.util.Arrays;

public class bench_sieve {
    static int sieve(int n) {
        byte[] flags = new byte[n + 1];
        Arrays.fill(flags, (byte) 1);
        flags[0] = 0;
        flags[1] = 0;
        for (int p = 2; (long) p * p <= n; p++) {
            if (flags[p] != 0) {
                for (int i = p * p; i <= n; i += p)
                    flags[i] = 0;
            }
        }
        int count = 0;
        for (int i = 2; i <= n; i++)
            if (flags[i] != 0) count++;
        return count;
    }

    public static void main(String[] args) {
        final int n = 10_000_000;
        long t0 = System.nanoTime();
        int count = sieve(n);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + count);
        System.out.println("elapsed: " + ms + " ms");
    }
}
