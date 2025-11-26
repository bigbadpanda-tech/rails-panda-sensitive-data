require "rails_helper"

RSpec.describe RailsPanda::SensitiveData::Encryption::Encryptor do
  let(:key_provider) do
    # Create a simple key provider for testing
    Class.new(ActiveRecord::Encryption::KeyProvider) do
      def initialize(primary_key)
        @primary_key = primary_key
      end

      def encryption_key = ActiveRecord::Encryption::Key.derive_from(@primary_key)

      def decryption_keys(encrypted_message) = [encryption_key]
    end.new("test-primary-key-for-sensitive-data")
  end
  let(:key) { key_provider.encryption_key }

  describe "#initialize" do
    it "sets default values" do
      encryptor = described_class.new

      expect(encryptor.instance_variable_get(:@nil_visible_in_db)).to be true
      expect(encryptor.instance_variable_get(:@empty_string_visible_in_db)).to be true
      expect(encryptor.instance_variable_get(:@whitespace_visible_in_db)).to be true
    end

    it "accepts custom nil_visible_in_db" do
      encryptor = described_class.new(nil_visible_in_db: false)

      expect(encryptor.instance_variable_get(:@nil_visible_in_db)).to be false
    end

    it "accepts custom empty_string_visible_in_db" do
      encryptor = described_class.new(empty_string_visible_in_db: false)

      expect(encryptor.instance_variable_get(:@empty_string_visible_in_db)).to be false
    end

    it "accepts custom whitespace_visible_in_db" do
      encryptor = described_class.new(whitespace_visible_in_db: false)

      expect(encryptor.instance_variable_get(:@whitespace_visible_in_db)).to be false
    end
  end

  describe "#encrypt" do
    let(:encryptor) { described_class.new }

    context "with present text" do
      it "encrypts the text" do
        result = encryptor.encrypt("test@example.com", key_provider: key_provider)

        expect(result).to be_present
        expect(result).not_to eq("test@example.com")
      end
    end

    context "with nil" do
      context "when nil_visible_in_db is true" do
        let(:encryptor) { described_class.new(nil_visible_in_db: true) }

        it "returns nil" do
          result = encryptor.encrypt(nil)

          expect(result).to be_nil
        end
      end

      context "when nil_visible_in_db is false" do
        # Note: empty_string_visible_in_db must also be false for this test to work,
        # because we need both nil and "" to be encrypted to verify they're distinguishable.
        # If empty_string_visible_in_db were true (default), encrypt("") would return ""
        # directly, not an encrypted blob, making the comparison impossible.
        let(:encryptor) { described_class.new(nil_visible_in_db: false, empty_string_visible_in_db: false) }

        it "encrypts nil using a sentinel value to distinguish from empty string" do
          # When nil_visible_in_db is false, nil is encrypted using a sentinel value
          # This allows distinguishing encrypted nil from encrypted empty string
          nil_encrypted = encryptor.encrypt(nil, key_provider: key_provider)
          empty_encrypted = encryptor.encrypt("", key_provider: key_provider)

          expect(nil_encrypted).to be_present
          expect(empty_encrypted).to be_present
          # They should produce different encrypted values
          expect(nil_encrypted).not_to eq(empty_encrypted)

          # When decrypting, nil should decrypt to nil, empty string to ""
          # First verify the encrypted values can be decrypted
          nil_decrypted = encryptor.decrypt(nil_encrypted, key_provider: key_provider)
          empty_decrypted = encryptor.decrypt(empty_encrypted, key_provider: key_provider)

          expect(nil_decrypted).to be_nil
          expect(empty_decrypted).to be_empty
        end
      end
    end

    context "with empty string" do
      context "when empty_string_visible_in_db is true" do
        let(:encryptor) { described_class.new(empty_string_visible_in_db: true) }

        it "returns empty string" do
          result = encryptor.encrypt("")

          expect(result).to be_empty
        end
      end

      context "when empty_string_visible_in_db is false" do
        let(:encryptor) { described_class.new(empty_string_visible_in_db: false) }

        it "encrypts the empty string" do
          result = encryptor.encrypt("")

          expect(result).to be_present
        end
      end
    end

    context "with whitespace-only string" do
      context "when whitespace_visible_in_db is true" do
        let(:encryptor) { described_class.new(whitespace_visible_in_db: true) }

        it "returns the whitespace string as-is" do
          result = encryptor.encrypt("   ")

          expect(result).to eq("   ")
        end
      end

      context "when whitespace_visible_in_db is false" do
        let(:encryptor) { described_class.new(whitespace_visible_in_db: false) }

        it "encrypts the whitespace string" do
          result = encryptor.encrypt("   ", key_provider: key_provider)

          expect(result).to be_present
          expect(result).not_to eq("   ")
        end
      end
    end

    context "with non-string, non-nil value" do
      it "calls super to handle the value" do
        # Non-string values (like Integer, Symbol) should be passed to super
        # Rails' encryptor will raise an error for non-string values
        # This tests the else branch: super (line 57)
        expect { encryptor.encrypt(123, key_provider: key_provider) }.to raise_error(ActiveRecord::Encryption::Errors::ForbiddenClass)
      end
    end
  end

  describe "#decrypt" do
    let(:encryptor) { described_class.new }

    context "with encrypted text" do
      it "decrypts the text" do
        encrypted = encryptor.encrypt("test@example.com", key_provider: key_provider)
        decrypted = encryptor.decrypt(encrypted, key_provider: key_provider)

        expect(decrypted).to eq("test@example.com")
      end
    end

    context "with empty string" do
      context "when empty_string_visible_in_db is true" do
        let(:encryptor) { described_class.new(empty_string_visible_in_db: true) }

        it "returns empty string" do
          result = encryptor.decrypt("")

          expect(result).to be_empty
        end
      end

      context "when empty_string_visible_in_db is false" do
        let(:encryptor) { described_class.new(empty_string_visible_in_db: false) }

        it "calls super which may raise an error" do
          expect { encryptor.decrypt("") }.to raise_error(ActiveRecord::Encryption::Errors::Base)
        end
      end
    end

    context "with nil" do
      context "when nil_visible_in_db is true" do
        let(:encryptor) { described_class.new(nil_visible_in_db: true) }

        it "returns nil" do
          result = encryptor.decrypt(nil)

          expect(result).to be_nil
        end
      end

      context "when nil_visible_in_db is false" do
        let(:encryptor) { described_class.new(nil_visible_in_db: false) }

        it "calls super which may raise an error for nil" do
          # When nil_visible_in_db is false, nil goes to super
          # Super will try to decrypt nil, which may raise an error
          expect { encryptor.decrypt(nil) }.to raise_error(ActiveRecord::Encryption::Errors::Base)
        end
      end
    end

    context "with whitespace-only string" do
      context "when whitespace_visible_in_db is true" do
        let(:encryptor) { described_class.new(whitespace_visible_in_db: true) }

        it "returns the whitespace string as-is" do
          result = encryptor.decrypt("   ")

          expect(result).to eq("   ")
        end
      end

      context "when whitespace_visible_in_db is false" do
        let(:encryptor) { described_class.new(whitespace_visible_in_db: false) }

        it "decrypts the whitespace string" do
          encrypted = encryptor.encrypt("   ", key_provider: key_provider)
          decrypted = encryptor.decrypt(encrypted, key_provider: key_provider)

          expect(decrypted).to eq("   ")
        end

        it "calls super which raises an error for unencrypted whitespace string" do
          # When whitespace_visible_in_db is false, unencrypted whitespace strings should raise an error
          expect { encryptor.decrypt("   ", key_provider: key_provider) }.to raise_error(ActiveRecord::Encryption::Errors::Base)
        end
      end
    end
  end
end
