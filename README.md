# Rails Panda Sensitive Data

A Rails gem that provides enhanced encryption capabilities for handling (and encrypting) sensitive data in ActiveRecord models.

## Features

- **Enhanced ActiveRecord encryption** - Extends Rails' built-in `encrypts` method with additional options
- **Multiple sensitive fields in one attribute** - Store multiple sensitive data fields in a single encrypted attribute using `has_sensitive_data`
- **Customizable empty string handling** - Control whether empty strings are visible in the database or encrypted
- **Nil value handling** - Option to control whether nil values are visible in the database or encrypted
- **Whitespace-only string handling** - Option to store whitespace-only strings as-is (space-saving for non-PII data)
- **Full dirty tracking support** - Complete ActiveRecord dirty tracking methods for sensitive data fields
- **Auto-inclusion** - Automatically included in all ActiveRecord::Base models
- **Rails 7.0+ compatible** - Built on top of ActiveRecord::Encryption

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rails-panda-sensitive-data"
```

And then execute:

```bash
$ bundle install
```

## Requirements

- Ruby >= 3.2
- Rails >= 7.0 (required for ActiveRecord::Encryption support)
- ActiveRecord::Encryption must be configured in your Rails application

## Configuration

### ActiveRecord::Encryption Setup

First, configure ActiveRecord::Encryption in your Rails application:

```ruby
# config/application.rb
config.active_record.encryption.primary_key = "your-primary-key-here"
config.active_record.encryption.deterministic_key = "your-deterministic-key-here"
config.active_record.encryption.key_derivation_salt = "your-key-derivation-salt-here"
```

I don't mention including this in `config/initializers/active_record_encryption.rb` because I've often run into problems with this approach. Namely that ActiveRecord was already initialized (read: had fetched these encryption keys) by the time the initializers started running.

## Usage

### Basic Setup

The module is automatically included in all ActiveRecord::Base models. No manual inclusion needed!

### Using `encrypts`

The `encrypts` method works like Rails' built-in method but with additional options:

```ruby
class User < ApplicationRecord
  encrypts :email
  encrypts :phone_number
end
```

#### Options

- `nil_visible_in_db` (default: `true`) - If `true`, nil values are stored as nil in the database (saves space, but visible). If `false`, nil values are encrypted using a sentinel value (`\0`) to distinguish them from encrypted empty strings.
- `empty_string_visible_in_db` (default: `true`) - If `true`, empty strings are stored as empty strings in the database (saves space, but visible). If `false`, they are encrypted.
- `whitespace_visible_in_db` (default: `true`) - If `true`, whitespace-only strings (e.g., "   ", "\t\n") are stored as-is in the database (saves space, no PII). If `false`, they are encrypted.
- `rails_default` (default: `false`) - If `true`, bypasses all custom logic and uses Rails' standard `encrypts` behavior.
- `encryptor` - Custom encryptor instance (if provided, custom encryptor won't be created automatically)
- All standard Rails `encrypts` options are also supported (e.g., `deterministic`, `key_provider`, etc.)

**Example:**

```ruby
class User < ApplicationRecord
  # Encrypt empty strings instead of storing them as-is
  encrypts :email, empty_string_visible_in_db: false

  # Encrypt nil values instead of storing them as nil
  encrypts :phone_number, nil_visible_in_db: false

  # Encrypt whitespace-only strings
  encrypts :notes, whitespace_visible_in_db: false

  # Use Rails' standard behavior (bypass custom logic)
  encrypts :backup_email, rails_default: true
end
```

**Trade-offs:**

- **Visible in DB (`true`)**: Saves space, faster queries, but values are visible in the database
- **Encrypted (`false`)**: More secure, but takes more space. Note: Encrypted empty/nil values can still be inferred from their shorter encrypted blob size.

### Using `has_sensitive_data`

Store multiple sensitive data fields in a single encrypted attribute:

```ruby
class User < ApplicationRecord
  has_sensitive_data :ssn, :credit_card, :bank_account
end
```

This will:
- Store all fields in a single `sensitive_data` encrypted attribute
- Provide accessor methods for each field (`ssn`, `credit_card`, `bank_account`)
- Automatically encrypt/decrypt the entire hash

**Example:**

```ruby
user = User.new
user.ssn = "123-45-6789"
user.credit_card = "4111-1111-1111-1111"
user.bank_account = "1234567890"
user.save!

# Reading values
user.ssn # => "123-45-6789"
user.credit_card # => "4111-1111-1111-1111"

# The sensitive_data attribute is encrypted
user.read_attribute(:sensitive_data) # => encrypted value, not plain hash
```

#### Options

- `in` (default: `:sensitive_data`) - The attribute name to store the encrypted hash
- All options from `encrypts` are also supported

**Example with custom attribute name:**

```ruby
class User < ApplicationRecord
  has_sensitive_data :ssn, :credit_card, in: :encrypted_pii
end
```

### Change Tracking

The gem provides change tracking methods for sensitive data fields:

```ruby
user = User.new
user.ssn = "123-45-6789"
user.save!

user.ssn = "999-99-9999"
user.ssn_changed? # => true
user.ssn_in_database # => "123-45-6789"

user.save!
user.saved_change_to_ssn? # => true
user.ssn_before_last_save # => "123-45-6789"
```

Available methods (matching Rails' standard dirty tracking API):
- `#{field}_changed?` - Returns true if the field has been changed but not saved
- `#{field}_in_database` - Returns the value currently stored in the database
- `#{field}_before_last_save` - Returns the value before the last save (nil until after a save, and nil after reload)
- `saved_change_to_#{field}?` - Returns true if the field was changed in the last save
- `saved_change_to_#{field}` - Returns `[before, after]` array if changed, or `nil`
- `will_save_change_to_#{field}?` - Returns true if the field will change on the next save
- `#{field}_change_to_be_saved` - Returns `[current_db_value, new_value]` array if there are pending changes, or `nil`

### Combining `encrypts` and `has_sensitive_data`

You can use both methods in the same model:

```ruby
class User < ApplicationRecord
  encrypts :email
  has_sensitive_data :ssn, :credit_card
end
```

## Advanced Usage

### Custom Encryptor

```ruby
custom_encryptor = RailsPanda::SensitiveData::Encryption::Encryptor.new(
  empty_string_visible_in_db: false,
  nil_visible_in_db: false,
  whitespace_visible_in_db: false
)

class User < ApplicationRecord
  encrypts :email, encryptor: custom_encryptor
end
```

**Note:** If you provide a custom `encryptor`, the gem will not automatically create a custom encryptor based on the visibility options. The provided encryptor will be used as-is.

### Key Management

The gem uses Rails' default key provider from your ActiveRecord::Encryption configuration. This supports deterministic encryption and follows Rails' standard key management practices. You can also provide a custom key provider if needed:

```ruby
# Uses Rails' default key provider (recommended)
class User < ApplicationRecord
  encrypts :email
end

# Or provide a custom key provider
custom_key_provider = ActiveRecord::Encryption::KeyProvider.new(primary_key: "your-key")

class User < ApplicationRecord
  encrypts :email, key_provider: custom_key_provider
end
```

## How It Works

### `encrypts`

This method extends Rails' built-in `encrypts` method with additional options for handling nil values, empty strings, and whitespace-only strings. It uses a custom `Encryptor` that wraps `ActiveRecord::Encryption::Encryptor` and provides space-saving options for non-sensitive values.

The custom encryptor is automatically created when visibility options are set to their default values (`true`). You can bypass custom logic entirely by passing `rails_default: true`.

### `has_sensitive_data`

This method:
1. Serializes multiple fields into a single Hash using YAML
2. Encrypts the entire Hash using `encrypts`
3. Provides accessor methods for each field
4. Handles nil values by removing them from the hash
5. Provides full dirty tracking support matching Rails' standard API

The encrypted hash is stored in a single database column, reducing the number of encrypted columns needed. All dirty tracking methods work exactly like Rails' built-in methods for regular attributes.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bigbadpanda-tech/rails-panda-sensitive-data.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
