# frozen_string_literal: true

require "active_support"
require "active_support/concern"

module RailsPanda
  module SensitiveData
    module Models
      module ActiveRecord
        extend ActiveSupport::Concern

        class_methods do
          def encrypts(*attributes, **options)
            raise ArgumentError, "encrypts must be called with at least one attribute" if attributes.blank?

            super_options = options.dup

            # If rails_default is true, skip our custom logic and use Rails' standard behavior
            unless super_options.delete(:rails_default)
              nil_visible_in_db = super_options.delete(:nil_visible_in_db) != false
              empty_string_visible_in_db = super_options.delete(:empty_string_visible_in_db) != false
              whitespace_visible_in_db = super_options.delete(:whitespace_visible_in_db) != false
              needs_custom_encryptor =
                nil_visible_in_db ||
                empty_string_visible_in_db ||
                whitespace_visible_in_db

              # Pass encryptor as a keyword argument - Rails stores it in context_properties internally and retrieves it from there when needed
              if needs_custom_encryptor && !super_options[:encryptor]
                super_options[:encryptor] =
                  ::RailsPanda::SensitiveData::Encryption::Encryptor.new(
                    empty_string_visible_in_db:,
                    nil_visible_in_db:,
                    whitespace_visible_in_db:
                  )
              end
            end

            super(*attributes, **super_options)
          end

          def has_sensitive_data(*attributes, **options)
            raise ArgumentError, "has_sensitive_data must be called with at least one attribute" if attributes.blank?

            super_options = options.dup

            in_attribute = super_options.delete(:in)&.to_sym || :sensitive_data

            unless @__has_registered_sensitive_data_encrypted_attribute
              serialize(in_attribute, type: Hash, coder: YAML)
              encrypts(in_attribute, **super_options)

              @__has_registered_sensitive_data_encrypted_attribute = true
            end

            attributes.each do |attr|
              attr = attr.to_sym

              define_method attr do
                the_hash = send(in_attribute)
                return if the_hash.blank?
                the_hash[attr]
              end

              define_method "#{attr}=" do |the_value|
                the_hash = send(in_attribute)
                the_hash ||= {}

                if the_value.nil?
                  the_hash.delete attr
                else
                  the_hash[attr] = the_value
                end

                send("#{in_attribute}=", the_hash)
              end

              attr_in_database = :"#{attr}_in_database"
              attr_before_last_save = :"#{attr}_before_last_save"
              saved_change_to_attr = :"saved_change_to_#{attr}"

              define_method attr_in_database do
                attribute_in_database(in_attribute)&.dig(attr)
              end

              # Returns nil until after a save, and nil after reload (Rails clears mutations_before_last_save on reload)
              define_method attr_before_last_save do
                attribute_before_last_save(in_attribute)&.dig(attr)
              end

              # attribute_changed? - Has this attribute changed from the database value?
              define_method "#{attr}_changed?" do
                send(attr) != send(attr_in_database)
              end

              # saved_change_to_attribute - Returns the change to an attribute during the last save
              define_method saved_change_to_attr do
                before = send(attr_before_last_save)
                current = send(attr)
                return nil if before.nil? || before == current
                [before, current]
              end

              # saved_change_to_attribute? - Did this attribute change when we last saved?
              # Returns false if before_last_save is nil (e.g., after reload or before any save)
              define_method "#{saved_change_to_attr}?" do
                before = send(attr_before_last_save)
                !before.nil? && send(attr) != before # No saved change if before_last_save is nil
              end

              # will_save_change_to_attribute? - Will this attribute change the next time we save?
              define_method "will_save_change_to_#{attr}?" do
                send(attr) != send(attr_in_database)
              end

              # attribute_change_to_be_saved - Returns the change to an attribute that will be persisted during the next save
              define_method "#{attr}_change_to_be_saved" do
                in_db = send(attr_in_database)
                current = send(attr)
                return nil if in_db.nil? || in_db == current
                [in_db, current]
              end
            end
          end
        end
      end
    end
  end
end

# Auto-include the module in all ActiveRecord::Base models
ActiveSupport.on_load(:active_record) do
  include RailsPanda::SensitiveData::Models::ActiveRecord
end
