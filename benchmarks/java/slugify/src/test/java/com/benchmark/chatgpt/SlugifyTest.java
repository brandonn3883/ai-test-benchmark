package com.benchmark.chatgpt;

import com.benchmark.Slugify;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * JUnit 5 tests for {@link Slugify} class.
 */
class SlugifyTest {

    private Slugify slugifyDefault;
    private Slugify slugifyUnderscore;
    private Slugify slugifyNoLowerCase;
    private Slugify slugifyTransliterator;

    @BeforeEach
    void setUp() {
        slugifyDefault = Slugify.builder().build();
        slugifyUnderscore = Slugify.builder().underscoreSeparator(true).build();
        slugifyNoLowerCase = Slugify.builder().lowerCase(false).build();
        slugifyTransliterator = Slugify.builder().transliterator(true).build();
    }

    /**
     * Test slugify with null input.
     */
    @Test
    void testSlugifyReturnsEmptyForNullInput() {
        assertEquals("", slugifyDefault.slugify(null));
    }

    /**
     * Test slugify with empty string.
     */
    @Test
    void testSlugifyReturnsEmptyForEmptyString() {
        assertEquals("", slugifyDefault.slugify(""));
    }

    /**
     * Test slugify with whitespace-only string.
     */
    @Test
    void testSlugifyTrimsWhitespace() {
        assertEquals("", slugifyDefault.slugify("   "));
    }

    /**
     * Test slugify with simple ASCII input.
     */
    @Test
    void testSlugifySimpleAscii() {
        assertEquals("hello-world", slugifyDefault.slugify("Hello World"));
    }

    /**
     * Test slugify with underscore separator.
     */
    @Test
    void testSlugifyUsesUnderscore() {
        assertEquals("hello_world", slugifyUnderscore.slugify("Hello World"));
    }

    /**
     * Test slugify with no lowercase option.
     */
    @Test
    void testSlugifyKeepsCaseWhenLowerCaseFalse() {
        assertEquals("Hello-World", slugifyNoLowerCase.slugify("Hello World"));
    }

    /**
     * Test slugify with transliteration enabled.
     */
    @Test
    void testSlugifyTransliteratesNonAscii() {
        String input = "Тест";
        String slug = slugifyTransliterator.slugify(input);
        assertNotNull(slug);
        assertTrue(slug.matches("[A-Za-z0-9\\-]+"));
    }

    /**
     * Test slugify with custom replacements.
     */
    @Test
    void testSlugifyWithCustomReplacements() {
        Map<String, String> customMap = new HashMap<>();
        customMap.put("hello", "hi");
        Slugify slugifyCustom = Slugify.builder().customReplacement("hello", "hi").build();
        assertEquals("hi-world", slugifyCustom.slugify("hello world"));
    }

    /**
     * Test slugify with multiple consecutive non-alphanumeric characters.
     */
    @Test
    void testSlugifyCollapsesMultipleNonAlphanumeric() {
        assertEquals("hello-world", slugifyDefault.slugify("Hello!!!   World"));
    }

    /**
     * Test slugify trims leading and trailing hyphens.
     */
    @Test
    void testSlugifyTrimsLeadingTrailingHyphens() {
        assertEquals("hello-world", slugifyDefault.slugify("!!!Hello World???"));
    }

    /**
     * Test replaceAll with empty map returns same input.
     */
    @Test
    void testReplaceAllWithEmptyMap() {
        assertEquals("test", slugifyDefault.slugify("test"));
    }

    /**
     * Test slugify with locale-specific behavior.
     */
    @Test
    void testSlugifyWithLocale() {
        Slugify slugifyLocale = Slugify.builder().locale(Locale.FRENCH).build();
        assertEquals("cote-d-ivoire", slugifyLocale.slugify("Côte d'Ivoire"));
    }

    /**
     * Test slugify with input that should be completely removed.
     */
    @Test
    void testSlugifyAllNonAsciiRemoved() {
        assertEquals("", slugifyDefault.slugify("®©✓"));
    }

    /**
     * Test slugify with numeric input.
     */
    @Test
    void testSlugifyNumbersRemain() {
        assertEquals("123-456", slugifyDefault.slugify("123 456"));
    }

    /**
     * Test slugify with special characters replaced by hyphen.
     */
    @Test
    void testSlugifySpecialCharacters() {
        assertEquals("hello-world", slugifyDefault.slugify("Hello@World!"));
    }

    /**
     * Test slugify with combination of options.
     */
    @Test
    void testSlugifyCombinedOptions() {
        Slugify s = Slugify.builder()
                .lowerCase(false)
                .underscoreSeparator(true)
                .transliterator(true)
                .build();
        assertEquals("Test_Slug", s.slugify("Tëst Šlug"));
    }
}
