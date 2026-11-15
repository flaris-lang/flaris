// bench_regex.java - scan a 9.8 MB corpus for YYYY-MM-DD dates, SCANS times.
// java.util.regex is a backtracking engine.
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class bench_regex {
    public static void main(String[] args) throws Exception {
        String text = Files.readString(Path.of("bench_corpus.txt"));
        final int scans = 5;
        Pattern re = Pattern.compile("\\b\\d{4}-\\d{2}-\\d{2}\\b");
        long t0 = System.nanoTime();
        int total = 0;
        for (int k = 0; k < scans; k++) {
            Matcher m = re.matcher(text);
            while (m.find()) total++;
        }
        long ms = (System.nanoTime() - t0) / 1_000_000;
        System.out.println("result: " + total);
        System.out.println("elapsed: " + ms + " ms");
    }
}
