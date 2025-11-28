import pytest
import re
from src.slugify import slugify, smart_truncate, DISALLOWED_CHARS_PATTERN, DISALLOWED_UNICODE_CHARS_PATTERN

@pytest.mark.parametrize(
    "input_str, max_length, word_boundary, separator, save_order, expected",
    [
        ("", 0, False, " ", False, ""),
        ("hello world", 0, False, " ", False, "hello world"),
        ("hello world", 5, False, " ", False, "hello"),
        ("hello world", 5, True, " ", False, "hello"),
        ("hello world", 5, True, " ", True, "hello"),
        ("hello", 10, True, " ", False, "hello"),
        ("   spaced   ", 5, False, " ", False, "spac"),
        ("one,two,three", 7, True, ",", False, "one,two"),
        ("one,two,three", 7, True, ",", True, "one"),
    ]
)
def test_smart_truncate_various_cases(input_str, max_length, word_boundary, separator, save_order, expected):
    """Test smart_truncate with various inputs, separators, and options."""
    assert smart_truncate(input_str, max_length, word_boundary, separator, save_order) == expected

def test_smart_truncate_empty_string():
    """Test smart_truncate with an empty string."""
    assert smart_truncate("", 10) == ""

def test_smart_truncate_none_input():
    """Test smart_truncate raises TypeError with None input."""
    with pytest.raises(TypeError):
        smart_truncate(None, 10)

@pytest.mark.parametrize(
    "text,expected",
    [
        ("Hello World!", "hello-world"),
        ("Café & Restaurant", "cafe-restaurant"),
        ("100% guaranteed", "100-guaranteed"),
        ("quotes' test", "quotes-test"),
        ("multiple   spaces", "multiple-spaces"),
        ("___underscores___", "underscores"),
        ("special@#%&*characters", "special-characters"),
        ("stop words test", "test"),
        ("replacements | test", "replacements-or-test"),
        ("HTML &copy; &#169; &#xA9;", "html-copyright"),
        ("MixedCASE", "mixedcase"),
        ("123,456,789", "123456789"),
    ]
)
def test_slugify_basic_cases(text, expected):
    """Test slugify with normal strings and common transformations."""
    stopwords = ("stop", "words")
    replacements = (["|", "or"],)
    result = slugify(
        text,
        stopwords=stopwords,
        replacements=replacements
    )
    assert result == expected

def test_slugify_allow_unicode():
    """Test slugify with allow_unicode=True preserves accented characters."""
    text = "Café Münchner Kindl"
    result = slugify(text, allow_unicode=True)
    assert "é" in result and "ü" in result

def test_slugify_disallowed_chars_custom_regex():
    """Test slugify with a custom regex pattern."""
    text = "Test$%Special#Characters!"
    custom_pattern = re.compile(r"[$%#!]+")
    result = slugify(text, regex_pattern=custom_pattern)
    assert result == "test-special-characters"

def test_slugify_max_length_truncate_word_boundary():
    """Test slugify truncates with word boundary and save_order."""
    text = "This is a test for slugify"
    result = slugify(text, max_length=10, word_boundary=True, save_order=True)
    assert result == "this-is-a"

def test_slugify_non_string_input():
    """Test slugify converts non-string input to string."""
    assert slugify(12345) == "12345"

def test_slugify_empty_string_and_none_stopwords():
    """Test slugify handles empty string and empty stopwords."""
    assert slugify("", stopwords=[]) == ""

def test_slugify_lowercase_option_false():
    """Test slugify with lowercase=False preserves original case."""
    text = "TestCase"
    result = slugify(text, lowercase=False)
    assert result == "TestCase"

def test_slugify_separator_replacement():
    """Test slugify changes default separator to custom separator."""
    text = "Hello World"
    result = slugify(text, separator="_")
    assert result == "hello_world"

def test_slugify_exceptions_handling():
    """Test slugify gracefully handles invalid decimal/hex HTML entities."""
    text = "Invalid &#xyz; &#xZZ;"
    result = slugify(text)
    assert "invalid" in result

def test_smart_truncate_returns_full_when_shorter():
    """Test smart_truncate returns full string if shorter than max_length."""
    assert smart_truncate("short", 10) == "short"
