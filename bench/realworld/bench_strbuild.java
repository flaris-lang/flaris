// bench_strbuild.java - build a large string, N times, via StringBuilder
// (Java's idiomatic linear builder; s += is O(n^2) because strings are
// immutable). result is the final length (ASCII, so chars = bytes).
public class bench_strbuild {
    public static void main(String[] args) {
        final int n = 1_000_000;
        long t0 = System.nanoTime();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            sb.append("item_").append(i).append(';');
        }
        int result = sb.length();
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + result);
        System.out.println("elapsed: " + ms + " ms");
    }
}
