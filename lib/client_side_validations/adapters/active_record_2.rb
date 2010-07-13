require 'validation_reflection'
require 'client_side_validations/adapters/orm_base'

ActiveRecord::Base.class_eval do
  ::ActiveRecordExtensions::ValidationReflection.reflected_validations << :validates_size_of
  ::ActiveRecordExtensions::ValidationReflection.install(self)
end

module DNCLabs
  module ClientSideValidations
    module Adapters
      class ActiveRecord2 < ORMBase

        def validation_to_hash(attr)
          base.class.reflect_on_validations_for(attr).inject({}) do |hash, validation|
            hash.merge!(build_validation_hash(validation.clone))
          end
        end
        
        def validation_fields
          base.class.reflect_on_all_validations.map { |v| v.name }.uniq
        end
        
        private
        
        def build_validation_hash(validation, message_key = 'message')
          if validation.macro == :validates_size_of
            validation.instance_variable_set('@macro', :validates_length_of)
          end
          if validation.macro == :validates_length_of &&
            (range = (validation.options.delete(:within) || validation.options.delete(:in)))
            validation.options[:minimum] = range.first
            validation.options[:maximum] = range.last
          elsif validation.macro == :validates_inclusion_of || validation.macro == :validates_exclusion_of
            validation.options[:in] = validation.options[:in].to_a
          end
          super
        end
        
        def supported_validation?(validation)
          SupportedValidations.include?(validation.macro.to_s.match(/\w+_(\w+)_\w+/)[1].to_sym)
        end
        
        def get_validation_message(validation)
          default = case validation.macro.to_sym
          when :validates_presence_of
            I18n.translate('activerecord.errors.messages.blank')
          when :validates_format_of
            I18n.translate('activerecord.errors.messages.invalid')
          when :validates_length_of
            if count = validation.options[:minimum]
              I18n.translate('activerecord.errors.messages.too_short').sub('{{count}}', count.to_s)
            elsif count = validation.options[:maximum]
              I18n.translate('activerecord.errors.messages.too_long').sub('{{count}}', count.to_s)
            end
          when :validates_numericality_of
            I18n.translate('activerecord.errors.messages.not_a_number')
          when :validates_uniqueness_of
            I18n.translate('activerecord.errors.messages.taken')
          when :validates_confirmation_of
            I18n.translate('activerecord.errors.messages.confirmation')
          when :validates_acceptance_of
            I18n.translate('activerecord.errors.messages.accepted')
          when :validates_inclusion_of
            I18n.translate('activerecord.errors.messages.inclusion')
          when :validates_exclusion_of
            I18n.translate('activerecord.errors.messages.exclusion')
          end
          
          message = validation.options.delete(:message)
          if message.kind_of?(String)
            message
          elsif message.kind_of?(Symbol)
            I18n.translate("activerecord.errors.models.#{base.class.to_s.downcase}.attributes.#{validation.name}.#{message}")
          else
            default
          end
        end

        def get_validation_method(validation)
          method = validation.macro.to_s
          method.match(/\w+_(\w+)_\w+/)[1]
        end
      end
    end
  end
end