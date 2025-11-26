require "rails_helper"

RSpec.describe RailsPanda::SensitiveData::Models::ActiveRecord do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Base.connection.create_table :test_users, force: true do |t|
      t.text :email
      t.text :phone
      t.text :sensitive_data
      t.text :custom_data
    end
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    ActiveRecord::Base.connection.drop_table :test_users, if_exists: true
  end

  let(:user_class) do
    Class.new(ApplicationRecord) do
      self.table_name = "test_users"
      # Module is auto-included via ActiveSupport.on_load(:active_record)
    end
  end

  describe ".encrypts" do
    context "with default options" do
      before do
        user_class.encrypts :email
      end

      it "encrypts the attribute" do
        user = user_class.create!(email: "test@example.com")
        user.reload

        # ActiveRecord::Encryption stores encrypted value in the same column
        # Use read_attribute_before_type_cast to get the raw database value
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).not_to eq("test@example.com")
        expect(encrypted_value).to be_present
      end

      it "decrypts the attribute when reading" do
        user = user_class.create!(email: "test@example.com")
        user.reload

        expect(user.email).to eq("test@example.com")
      end

      it "handles nil values" do
        user = user_class.create!(email: nil)
        user.reload

        # With default options (nil_visible_in_db: true), nil is stored as nil
        expect(user.email).to be_nil
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_nil
      end

      it "handles empty string values" do
        user = user_class.create!(email: "")
        user.reload

        # With default options (empty_string_visible_in_db: true), empty strings are stored as ""
        expect(user.email).to eq("")
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to eq("")
      end

      it "handles whitespace-only string values" do
        user = user_class.create!(email: "   ")
        user.reload

        # With default options (whitespace_visible_in_db: true), whitespace-only strings are stored as-is
        expect(user.email).to eq("   ")
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to eq("   ")
      end
    end

    context "with custom encryptor" do
      before do
        # Use Rails' default encryptor instead of our custom one
        # This tests that when an encryptor is explicitly passed, Rails uses it and doesn't create our custom encryptor automatically (which would store empty strings as "")
        user_class.encrypts :email, encryptor: ActiveRecord::Encryption::Encryptor.new
      end

      it "encrypts content correctly" do
        user = user_class.create!(email: "test@example.com")
        user.reload

        expect(user.email).to eq("test@example.com")
        # Verify encryption happened (value is different from plaintext)
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).not_to eq("test@example.com")
        expect(encrypted_value).to be_present
      end

      it "uses Rails' default encryptor behavior for nil values (stores as nil)" do
        # Our custom encryptor (with default options) stores nil as nil
        # Rails' default encryptor also stores nil as nil
        # This test verifies that Rails' encryptor is being used
        user = user_class.create!(email: nil)
        user.reload

        expect(user.email).to be_nil
        # With Rails' default encryptor, nil is stored as nil (not encrypted)
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_nil
      end

      it "uses Rails' default encryptor behavior for empty strings (encrypts them, doesn't store as '')" do
        # Our custom encryptor (with default options) stores empty strings as ""
        # Rails' default encryptor encrypts empty strings
        # This test verifies that Rails' encryptor is being used, not ours
        user = user_class.create!(email: "")
        user.reload

        expect(user.email).to eq("")
        # With Rails' default encryptor, empty strings are encrypted (not stored as "")
        # This is different from our custom encryptor's default behavior
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_present
      end

      it "uses Rails' default encryptor behavior for whitespace-only strings (encrypts them)" do
        # Our custom encryptor (with default options) stores whitespace-only strings as-is
        # Rails' default encryptor encrypts whitespace-only strings
        # This test verifies that Rails' encryptor is being used, not ours
        user = user_class.create!(email: "   ")
        user.reload

        expect(user.email).to eq("   ")
        # With Rails' default encryptor, whitespace strings are encrypted (not stored as-is)
        # This is different from our custom encryptor's default behavior
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_present
        expect(encrypted_value).not_to eq("   ")
      end
    end

    context "with empty_string_visible_in_db: false" do
      before do
        user_class.encrypts :email, empty_string_visible_in_db: false
      end

      it "encrypts empty strings" do
        user = user_class.create!(email: "")
        user.reload

        expect(user.email).to eq("")
        # With empty_string_visible_in_db: false, empty strings should be encrypted
        encrypted_value = user.read_attribute_before_type_cast(:email)
        # Empty strings are encrypted (not stored as empty strings)
        expect(encrypted_value).to be_present
      end
    end

    context "with nil_visible_in_db: false" do
      before do
        user_class.encrypts :email, nil_visible_in_db: false
      end

      it "encrypts nil values using a sentinel to distinguish from empty string" do
        user = user_class.create!(email: nil)
        user.reload

        # When nil_visible_in_db is false, nil is encrypted using a sentinel value (\0)
        # This allows distinguishing encrypted nil from encrypted empty string
        # After decryption, it will be nil (not "")
        expect(user.email).to be_nil
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_present
      end
    end

    context "with whitespace_visible_in_db: false" do
      before do
        user_class.encrypts :email, whitespace_visible_in_db: false
      end

      it "encrypts various whitespace-only strings" do
        [" ", "\t", "\n", " \t\n ", "\r\n"].each do |whitespace_str|
          user = user_class.create!(email: whitespace_str)
          user.reload

          expect(user.email).to eq(whitespace_str)
          # With whitespace_visible_in_db: false, whitespace strings should be encrypted
          encrypted_value = user.read_attribute_before_type_cast(:email)
          # Whitespace strings are encrypted (not stored as-is)
          expect(encrypted_value).not_to eq(whitespace_str)
          expect(encrypted_value).to be_present
        end
      end
    end

    context "with rails_default: true" do
      before do
        user_class.encrypts :email, rails_default: true
      end

      it "behaves exactly like standard Rails encrypts" do
        user = user_class.create!(email: "test@example.com")
        user.reload

        expect(user.email).to eq("test@example.com")
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).not_to eq("test@example.com")
        expect(encrypted_value).to be_present
      end

      it "encrypts empty strings (standard Rails behavior)" do
        user = user_class.create!(email: "")
        user.reload

        # Standard Rails encrypts empty strings
        expect(user.email).to eq("")
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_present # Empty string is encrypted
      end

      it "stores nil as nil (standard Rails behavior)" do
        user = user_class.create!(email: nil)
        user.reload

        # Standard Rails stores nil as nil
        expect(user.email).to be_nil
        encrypted_value = user.read_attribute_before_type_cast(:email)
        expect(encrypted_value).to be_nil
      end
    end

    context "with blank attributes" do
      it "raises an error" do
        expect { user_class.encrypts }.to raise_error(ArgumentError, "encrypts must be called with at least one attribute")
      end
    end
  end

  describe ".has_sensitive_data" do
    context "with default options" do
      before do
        user_class.has_sensitive_data :ssn, :credit_card
      end

      it "encrypts the sensitive_data attribute" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!
        user.reload

        expect(user.ssn).to eq("123-45-6789")

        # The sensitive_data attribute should be encrypted
        encrypted_value = user.read_attribute_before_type_cast(:sensitive_data)
        expect(encrypted_value).to be_present
        expect(encrypted_value).not_to eq({ssn: "123-45-6789"}.to_yaml)
        expect(encrypted_value).not_to match(/123-45-6789/)
      end

      it "handles nil values" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!
        user.reload

        user.ssn = nil
        user.save!

        expect(user.ssn).to be_nil
        expect(user.sensitive_data).not_to have_key(:ssn)
      end

      it "handles multiple attributes" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.credit_card = "4111-1111-1111-1111"
        user.save!

        expect(user.ssn).to eq("123-45-6789")
        expect(user.credit_card).to eq("4111-1111-1111-1111")
      end

      it "provides a _in_database method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!

        user.ssn = "999-99-9999"

        expect(user.ssn_in_database).to eq("123-45-6789")
        expect(user.ssn).to eq("999-99-9999")
      end

      it "provides a _before_last_save method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!

        user.ssn = "999-99-9999"
        user.save!

        expect(user.ssn_before_last_save).to eq("123-45-6789")
      end

      it "provides a saved_change_to_? method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!
        user.reload

        user.ssn = "999-99-9999"
        # Before saving, saved_change_to_ssn? should be false (no save has occurred yet)
        # Note: After reload, before_last_save is nil, so saved_change_to_ssn? returns false
        expect(user.saved_change_to_ssn?).to be false

        user.save!
        # After save (before reload), ssn_before_last_save should reflect the value before the save
        expect(user.saved_change_to_ssn?).to be true
        expect(user.ssn_before_last_save).to eq("123-45-6789")

        user.reload
        # After reload, attribute_before_last_save returns nil
        expect(user.saved_change_to_ssn?).to be false
        expect(user.ssn_before_last_save).to be_nil
        expect(user.ssn).to eq("999-99-9999")
      end

      it "provides a _changed? method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!

        user.ssn = "999-99-9999"
        expect(user.ssn_changed?).to be true

        user.save!
        expect(user.ssn_changed?).to be false
      end

      it "provides a saved_change_to_ method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!
        user.reload

        user.ssn = "999-99-9999"
        # Before saving, saved_change_to_ssn should be nil (no save has occurred yet)
        expect(user.saved_change_to_ssn).to be_nil

        user.save!
        # After save (before reload), saved_change_to_ssn should return [before, after]
        expect(user.saved_change_to_ssn).to eq(["123-45-6789", "999-99-9999"])

        user.reload
        # After reload, saved_change_to_ssn returns nil
        expect(user.saved_change_to_ssn).to be_nil
      end

      it "provides a will_save_change_to_? method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!

        user.ssn = "999-99-9999"
        # Before saving, will_save_change_to_ssn? should be true (value has changed)
        expect(user.will_save_change_to_ssn?).to be true

        user.save!
        # After saving, will_save_change_to_ssn? should be false (no pending changes)
        expect(user.will_save_change_to_ssn?).to be false
      end

      it "provides a _change_to_be_saved method" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!

        user.ssn = "999-99-9999"
        # Before saving, ssn_change_to_be_saved should return [current_db_value, new_value]
        expect(user.ssn_change_to_be_saved).to eq(["123-45-6789", "999-99-9999"])

        user.save!
        # After saving, ssn_change_to_be_saved should be nil (no pending changes)
        expect(user.ssn_change_to_be_saved).to be_nil
      end

      context "when sensitive data has not been setup" do
        it "_in_database returns nil" do
          user = user_class.new
          # Stub attribute_in_database to return nil
          # # This ensures we cover the possibility of no sensitive data being setup
          allow(user).to receive(:attribute_in_database).with(:sensitive_data).and_return(nil)

          result = user.ssn_in_database

          expect(result).to be_nil
        end
      end

      it "persists data across reloads" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.credit_card = "4111-1111-1111-1111"
        user.save!

        user.reload

        expect(user.ssn).to eq("123-45-6789")
        expect(user.credit_card).to eq("4111-1111-1111-1111")
      end
    end

    context "with custom in attribute" do
      before do
        user_class.has_sensitive_data :ssn, in: :custom_data
      end

      it "stores sensitive data in the custom attribute" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.save!
        user.reload

        expect(user.ssn).to eq("123-45-6789")
        expect(user.custom_data).to be_present

        expect(user.sensitive_data).to be_nil
      end
    end

    context "with blank attributes" do
      it "raises an error" do
        expect { user_class.has_sensitive_data }.to raise_error(ArgumentError, "has_sensitive_data must be called with at least one attribute")
      end
    end

    context "when called multiple times" do
      before do
        user_class.has_sensitive_data :ssn
        user_class.has_sensitive_data :credit_card
      end

      it "does not call `.serialize` again when called multiple times" do
        # `.serialize` was already called in the before block, so we expect 0 more calls
        allow(user_class).to receive(:serialize).and_call_original

        user_class.has_sensitive_data :another_field

        expect(user_class).not_to have_received(:serialize)
      end

      it "adds new attributes to existing sensitive_data" do
        user = user_class.new
        user.ssn = "123-45-6789"
        user.credit_card = "4111-1111-1111-1111"
        user.save!
        user.reload

        expect(user.ssn).to eq("123-45-6789")
        expect(user.credit_card).to eq("4111-1111-1111-1111")
      end
    end
  end

  describe "integration" do
    before do
      user_class.encrypts :email
      user_class.has_sensitive_data :ssn
    end

    it "works with both encrypts and has_sensitive_data" do
      user = user_class.new
      user.email = "test@example.com"
      user.ssn = "123-45-6789"
      user.save!

      expect(user.email).to eq("test@example.com")
      expect(user.ssn).to eq("123-45-6789")

      user.reload

      expect(user.email).to eq("test@example.com")
      expect(user.ssn).to eq("123-45-6789")
    end
  end
end
