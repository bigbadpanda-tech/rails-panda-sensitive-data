# frozen_string_literal: true

# :nocov:
# We do not collect coverage for this file because the coverage tool cannot correctly analyze the coverage in this file, due to the way these methods are (re)implemented.

module ActiveRecord
  module Encryption
    class EncryptedAttributeType
      alias_method :deserialize_original, :deserialize
      alias_method :serialize_with_current_original, :serialize_with_current

      # Override deserialize to ensure our custom decryptor converts the sentinel back to nil
      def deserialize(value)
        deserialize_original(value).then do |result|
          # Check special values
          if result == RailsPanda::SensitiveData::Encryption::Encryptor::NIL_SENTINEL
            rails_panda_encryptor&.then do |enc|
              return nil if !enc.instance_variable_get(:@nil_visible_in_db)
            end
          end
          result
        end
      end

      private

      # Override serialize_with_current to handle nil values when nil_visible_in_db is false
      # Rails' EncryptedAttributeType checks for nil before calling encrypt, so we need to convert nil to our sentinel value before Rails processes it
      def serialize_with_current(value)
        if value.nil?
          rails_panda_encryptor&.then do |enc|
            return nil if enc.instance_variable_get(:@nil_visible_in_db)

            # Convert nil to sentinel value and encrypt it directly
            # We need to encrypt it ourselves because Rails' serialize_with_current might store single-byte values directly without encryption
            # Get the key_provider from the scheme or use the default
            key_provider = scheme&.key_provider
            key_provider ||= scheme&.instance_variable_get(:@key_provider_param)
            key_provider ||= ActiveRecord::Encryption.config.then do |config|
              config.is_a?(ActiveRecord::Encryption::KeyProvider) ? config : nil
            end

            encrypted_sentinel = enc.encrypt(
              RailsPanda::SensitiveData::Encryption::Encryptor::NIL_SENTINEL,
              key_provider: key_provider
            )
            return encrypted_sentinel
          end
        end

        serialize_with_current_original(value)
      end

      def rails_panda_encryptor
        scheme&.instance_variable_get(:@context_properties)&.then do |props|
          if props.is_a?(Hash)
            # Get the encryptor from the scheme's context_properties
            enc = props[:encryptor]
            enc.is_a?(RailsPanda::SensitiveData::Encryption::Encryptor) ? enc : nil
          end
        end
      end
    end
  end
end
