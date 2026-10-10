require "test_helper"

class SecretCipherTest < ActiveSupport::TestCase
  setup do
    @key = MasterKey.parse("ab" * 32)
    @cipher = SecretCipher.new(@key)
  end

  test "round-trips a value, including unicode, newlines and the empty string" do
    [ "postgres://user:p@ss@host/db", "naïve — ✓\nline two", "", "x" * 10_000 ].each do |value|
      sealed = @cipher.encrypt(value, context: "production/DATABASE_URL")
      assert_equal value, @cipher.decrypt(sealed.ciphertext, sealed.wrapped_key, context: "production/DATABASE_URL")
    end
  end

  test "the stored bytes do not contain the plaintext, and differ every time" do
    first = @cipher.encrypt("super-secret-value", context: "production/A")
    second = @cipher.encrypt("super-secret-value", context: "production/A")

    assert_not_includes first.ciphertext, "super-secret-value"
    assert_not_equal first.ciphertext, second.ciphertext
    assert_not_equal first.wrapped_key, second.wrapped_key
    assert_equal 12 + 16 + 32, first.wrapped_key.bytesize
  end

  test "the wrong master key cannot decrypt" do
    sealed = @cipher.encrypt("value", context: "production/A")
    other = SecretCipher.new(MasterKey.parse("cd" * 32))

    error = assert_raises(SecretCipher::DecryptionError) { other.decrypt(sealed.ciphertext, sealed.wrapped_key, context: "production/A") }
    assert_match "master key is wrong or the stored value was altered", error.message
  end

  test "a secret moved to another name or environment does not decrypt" do
    sealed = @cipher.encrypt("value", context: "staging/API_KEY")

    assert_raises(SecretCipher::DecryptionError) { @cipher.decrypt(sealed.ciphertext, sealed.wrapped_key, context: "production/API_KEY") }
    assert_raises(SecretCipher::DecryptionError) { @cipher.decrypt(sealed.ciphertext, sealed.wrapped_key, context: "staging/OTHER") }
  end

  test "any altered byte is detected" do
    sealed = @cipher.encrypt("value", context: "production/A")

    [ 0, 12, 28, sealed.ciphertext.bytesize - 1 ].each do |index|
      tampered = sealed.ciphertext.dup.tap { |bytes| bytes.setbyte(index, bytes.getbyte(index) ^ 1) }
      assert_raises(SecretCipher::DecryptionError, "byte #{index}") { @cipher.decrypt(tampered, sealed.wrapped_key, context: "production/A") }
    end

    wrapped = sealed.wrapped_key.dup.tap { |bytes| bytes.setbyte(40, bytes.getbyte(40) ^ 1) }
    assert_raises(SecretCipher::DecryptionError) { @cipher.decrypt(sealed.ciphertext, wrapped, context: "production/A") }
    assert_raises(SecretCipher::DecryptionError) { @cipher.decrypt("short", sealed.wrapped_key, context: "production/A") }
  end

  test "rewrapping moves a secret to a new master key without changing its ciphertext" do
    sealed = @cipher.encrypt("value", context: "production/A")
    new_key = MasterKey.parse("cd" * 32)
    rewrapped = @cipher.rewrap(sealed.wrapped_key, new_key, context: "production/A")

    assert_equal "value", SecretCipher.new(new_key).decrypt(sealed.ciphertext, rewrapped, context: "production/A")
    assert_raises(SecretCipher::DecryptionError) { @cipher.decrypt(sealed.ciphertext, rewrapped, context: "production/A") }
  end

  test "the master key must be 64 hexadecimal characters" do
    assert_equal 32, MasterKey.parse("AB" * 32).bytesize
    assert_equal 32, MasterKey.parse(MasterKey.generate).bytesize

    [ nil, "", "abc", "zz" * 32, "ab" * 31, "ab" * 33 ].each do |bad|
      assert_raises(MasterKey::Missing, bad.inspect) { MasterKey.parse(bad) }
    end
  end
end
