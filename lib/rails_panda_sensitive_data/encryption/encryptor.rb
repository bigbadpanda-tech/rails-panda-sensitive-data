# frozen_string_literal: true

module RailsPanda
  module SensitiveData
    module Encryption
      class Encryptor < ::ActiveRecord::Encryption::Encryptor
        # Sentinel value to distinguish encrypted nil from encrypted empty string.
        # When nil_visible_in_db is false, we encrypt nil using this sentinel value (\0) instead of an empty string, allowing us to distinguish between encrypted nil and encrypted empty string during decryption.
        NIL_SENTINEL = "\0"

        # Custom encryptor that provides control over how nil, empty strings, and whitespace-only strings are stored.
        #
        # @param nil_visible_in_db [Boolean] When true (default), stores nil as nil in the database.
        #   This saves space and allows nil values to be queried directly, but makes them visible.
        #   When false, encrypts nil using a sentinel value. This hides nil values but takes more space.
        #   Note: Encrypted empty values can still be inferred from their shorter encrypted blob size.
        #
        # @param empty_string_visible_in_db [Boolean] When true (default), stores empty strings as ""
        #   in the database. This saves space and allows empty strings to be queried directly, but makes them visible. When false, encrypts empty strings normally. This hides empty strings but takes more space. Note: Encrypted empty values can still be inferred from their shorter encrypted blob size.
        #
        # @param whitespace_visible_in_db [Boolean] When true (default), stores whitespace-only strings (e.g., "   ", "\t\n") as-is in the database. This saves space since whitespace-only strings contain no PII or sensitive data. When false, encrypts whitespace-only strings normally.
        #
        # Trade-offs:
        # - true: Saves space, faster queries, but values are visible in the database
        # - false: Encrypts values (more secure), but takes more space and encrypted blobs can be inferred as empty/nil from their size
        def initialize(
          nil_visible_in_db: true,
          empty_string_visible_in_db: true,
          whitespace_visible_in_db: true
        )
          super()

          @nil_visible_in_db = nil_visible_in_db
          @empty_string_visible_in_db = empty_string_visible_in_db
          @whitespace_visible_in_db = whitespace_visible_in_db
        end

        def encrypt(clear_text, **options)
          if clear_text.nil?
            if @nil_visible_in_db
              nil
            else
              # When nil_visible_in_db is false, encrypt nil using a sentinel value
              # This allows us to distinguish encrypted nil from encrypted empty string
              # Rails' encryptor only accepts strings, so we use a null byte as sentinel
              super(NIL_SENTINEL, **options)
            end
          elsif clear_text.is_a?(String)
            if @empty_string_visible_in_db && clear_text == ""
              ""
            elsif @whitespace_visible_in_db && whitespace_only?(clear_text)
              clear_text
            else
              super
            end
          else
            super
          end
        end

        def decrypt(encrypted_text, **options)
          if @nil_visible_in_db && encrypted_text.nil?
            nil
          elsif @empty_string_visible_in_db && encrypted_text.is_a?(String) && encrypted_text == ""
            ""
          elsif @whitespace_visible_in_db && encrypted_text.is_a?(String) && whitespace_only?(encrypted_text)
            encrypted_text
          else
            decrypted = super
            # If decrypted value is the nil sentinel, return nil instead
            if decrypted == NIL_SENTINEL && !@nil_visible_in_db
              nil
            else
              decrypted
            end
          end
        end

        private

        # Check if a string contains only whitespace characters (spaces, tabs, newlines, etc.) but is not empty (empty strings are handled separately)
        def whitespace_only?(str)
          !str.empty? && str.strip.empty?
        end
      end
    end
  end
end
