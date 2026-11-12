package com.bullbitcoin.secrets;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.SeekableByteChannel;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.NoSuchFileException;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.StandardOpenOption;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserFactory;

/**
 * Reads fixed source files without SharedPreferences, whose load can restore a .bak.
 * A snapshot never repairs a file. Unexpected state is unavailable, not empty.
 */
final class LegacyPreferencesSnapshot {
    static final String DATA = "FlutterSecureStorage";
    static final String KEYS = "FlutterSecureKeyStorage";
    static final String CONFIG = "FlutterSecureStorageConfiguration";
    static final String NAMED_CONFIG = CONFIG + ":" + DATA;
    static final String HINT = "FlutterSharedPreferences";
    private static final String[] NAMES = {DATA, KEYS, CONFIG, NAMED_CONFIG, HINT};
    // A limit is a safe refusal, never a truncated inventory.
    private static final int MAX_FILE_BYTES = 16 * 1024 * 1024;

    private final Path directory;
    private final Map<String, byte[]> bytes = new LinkedHashMap<>();
    private final Map<String, Map<String, Object>> values = new HashMap<>();

    LegacyPreferencesSnapshot(Path directory) throws LegacyReadException {
        this.directory = directory;
        for (String name : NAMES) {
            byte[] content = readFile(name);
            bytes.put(name, content);
            values.put(name, content == null ? Collections.emptyMap() : parse(content));
        }
        verifyUnchanged();
    }

    Map<String, Object> get(String name) {
        return values.get(name);
    }

    boolean hasFile(String name) {
        return bytes.get(name) != null;
    }

    void verifyUnchanged() throws LegacyReadException {
        for (String name : NAMES) {
            if (!Arrays.equals(bytes.get(name), readFile(name))) {
                throw new LegacyReadException("changed");
            }
        }
    }

    private byte[] readFile(String name) throws LegacyReadException {
        Path file = directory.resolve(name + ".xml");
        Path backup = directory.resolve(name + ".xml.bak");
        try {
            if (Files.isSymbolicLink(directory) || exists(backup)) {
                throw new LegacyReadException("inconsistent");
            }
            if (!exists(file)) return null;
            if (!Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS)) {
                throw new LegacyReadException("inconsistent");
            }
            byte[] result;
            try (SeekableByteChannel input = Files.newByteChannel(
                    file, StandardOpenOption.READ, LinkOption.NOFOLLOW_LINKS)) {
                long size = input.size();
                if (size <= 0 || size > MAX_FILE_BYTES) throw new LegacyReadException("unreadable");
                ByteBuffer buffer = ByteBuffer.allocate((int) size);
                while (buffer.hasRemaining()) {
                    if (input.read(buffer) < 0) throw new LegacyReadException("changed");
                }
                if (input.read(ByteBuffer.allocate(1)) != -1) throw new LegacyReadException("changed");
                result = buffer.array();
            }
            if (exists(backup)) {
                throw new LegacyReadException("inconsistent");
            }
            return result;
        } catch (IOException | SecurityException e) {
            throw new LegacyReadException("unreadable");
        }
    }

    private static boolean exists(Path file) throws IOException {
        try {
            Files.readAttributes(file, BasicFileAttributes.class, LinkOption.NOFOLLOW_LINKS);
            return true;
        } catch (NoSuchFileException e) {
            return false;
        }
    }

    static Map<String, Object> parse(byte[] content) throws LegacyReadException {
        try {
            XmlPullParserFactory factory = XmlPullParserFactory.newInstance();
            factory.setNamespaceAware(true);
            XmlPullParser parser = factory.newPullParser();
            // Some Android-compatible parsers reject this feature even when set false.
            // Never proceed with declaration processing enabled; nextToken rejects the declaration itself.
            if (parser.getFeature(XmlPullParser.FEATURE_PROCESS_DOCDECL)) {
                throw new LegacyReadException("unreadable");
            }
            parser.setInput(new ByteArrayInputStream(content), "UTF-8");
            if (structural(parser) != XmlPullParser.START_TAG || !"map".equals(parser.getName())
                    || parser.getAttributeCount() != 0 || !parser.getNamespace().isEmpty()) {
                throw new LegacyReadException("unreadable");
            }
            Map<String, Object> result = new LinkedHashMap<>();
            int token;
            while ((token = structural(parser)) == XmlPullParser.START_TAG) {
                String type = parser.getName();
                String name = parser.getAttributeValue(null, "name");
                if (name == null || result.containsKey(name) || !parser.getNamespace().isEmpty()) {
                    throw new LegacyReadException("unreadable");
                }
                Object value;
                if ("string".equals(type)) {
                    attributes(parser, Collections.singleton("name"));
                    value = string(parser);
                } else if ("set".equals(type)) {
                    attributes(parser, Collections.singleton("name"));
                    Set<String> set = new HashSet<>();
                    while ((token = structural(parser)) == XmlPullParser.START_TAG) {
                        if (!"string".equals(parser.getName()) || parser.getAttributeCount() != 0
                                || !parser.getNamespace().isEmpty()) {
                            throw new LegacyReadException("unreadable");
                        }
                        if (!set.add(string(parser))) throw new LegacyReadException("unreadable");
                    }
                    if (token != XmlPullParser.END_TAG || !"set".equals(parser.getName())) {
                        throw new LegacyReadException("unreadable");
                    }
                    value = Collections.unmodifiableSet(set);
                } else {
                    attributes(parser, new HashSet<>(Arrays.asList("name", "value")));
                    String raw = parser.getAttributeValue(null, "value");
                    if (raw == null) throw new LegacyReadException("unreadable");
                    switch (type) {
                        case "boolean":
                            if (!raw.equals("true") && !raw.equals("false")) {
                                throw new LegacyReadException("unreadable");
                            }
                            value = Boolean.valueOf(raw);
                            break;
                        case "int": value = Integer.valueOf(raw); break;
                        case "long": value = Long.valueOf(raw); break;
                        case "float": value = Float.valueOf(raw); break;
                        default: throw new LegacyReadException("unsupported");
                    }
                    if (structural(parser) != XmlPullParser.END_TAG || !type.equals(parser.getName())) {
                        throw new LegacyReadException("unreadable");
                    }
                }
                result.put(name, value);
            }
            if (token != XmlPullParser.END_TAG || !"map".equals(parser.getName())
                    || structural(parser) != XmlPullParser.END_DOCUMENT) {
                throw new LegacyReadException("unreadable");
            }
            return Collections.unmodifiableMap(result);
        } catch (LegacyReadException e) {
            throw e;
        } catch (Exception e) {
            throw new LegacyReadException("unreadable");
        }
    }

    private static void attributes(XmlPullParser parser, Set<String> expected) throws LegacyReadException {
        if (parser.getAttributeCount() != expected.size()) throw new LegacyReadException("unreadable");
        for (int i = 0; i < parser.getAttributeCount(); i++) {
            if (!expected.contains(parser.getAttributeName(i))
                    || !parser.getAttributeNamespace(i).isEmpty()) {
                throw new LegacyReadException("unreadable");
            }
        }
    }

    private static int structural(XmlPullParser parser) throws Exception {
        while (true) {
            int token = parser.nextToken();
            if (token == XmlPullParser.COMMENT || token == XmlPullParser.IGNORABLE_WHITESPACE) continue;
            if (token == XmlPullParser.TEXT && parser.isWhitespace()) continue;
            if (token == XmlPullParser.START_TAG || token == XmlPullParser.END_TAG
                    || token == XmlPullParser.END_DOCUMENT) return token;
            throw new LegacyReadException("unreadable");
        }
    }

    private static String string(XmlPullParser parser) throws Exception {
        StringBuilder text = new StringBuilder();
        while (true) {
            int token = parser.nextToken();
            if (token == XmlPullParser.END_TAG && "string".equals(parser.getName())) return text.toString();
            if (token == XmlPullParser.TEXT || token == XmlPullParser.CDSECT
                    || token == XmlPullParser.IGNORABLE_WHITESPACE) {
                text.append(parser.getText());
            } else if (token == XmlPullParser.ENTITY_REF && parser.getText() != null) {
                String entity = parser.getName();
                if (!Arrays.asList("amp", "lt", "gt", "apos", "quot").contains(entity) && !entity.startsWith("#")) {
                    throw new LegacyReadException("unreadable");
                }
                text.append(parser.getText());
            } else {
                throw new LegacyReadException("unreadable");
            }
        }
    }
}
