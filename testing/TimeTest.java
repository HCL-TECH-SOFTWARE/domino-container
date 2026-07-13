import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.TimeZone;

public class TimeTest {

    private static final DateTimeFormatter FORMATTER =
            DateTimeFormatter.ISO_OFFSET_DATE_TIME;

    public static void main(String[] args) {

        boolean json = false;
        for (String arg : args) {
            if ("-json".equalsIgnoreCase(arg)) {
                json = true;
                break;
            }
        }

        ZoneId defaultZone = ZoneId.systemDefault();

        String timeZone = TimeZone.getDefault().getID();
        String zoneId = defaultZone.toString();
        String currentTime = ZonedDateTime.now(defaultZone)
                .toOffsetDateTime()
                .format(FORMATTER);
        String currentUtcTime = ZonedDateTime.now(ZoneId.of("UTC"))
                .toOffsetDateTime()
                .format(FORMATTER);
        String instant = Instant.now().toString();
        long epochMillis = System.currentTimeMillis();

        if (json) {
            System.out.println("{");
            System.out.println("  \"defaultTimeZone\": \"" + escape(timeZone) + "\",");
            System.out.println("  \"defaultZoneId\": \"" + escape(zoneId) + "\",");
            System.out.println("  \"currentTime\": \"" + currentTime + "\",");
            System.out.println("  \"currentUtcTime\": \"" + currentUtcTime + "\",");
            System.out.println("  \"instant\": \"" + instant + "\",");
            System.out.println("  \"epochMillis\": " + epochMillis);
            System.out.println("}");
        } else {
            System.out.println("Default TimeZone : " + timeZone);
            System.out.println("Default ZoneId   : " + zoneId);
            System.out.println("Current TZ Time  : " + currentTime);
            System.out.println("Current UTC Time : " + currentUtcTime);
            System.out.println("Instant (UTC)    : " + instant);
            System.out.println("Epoch millis     : " + epochMillis);
        }
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
