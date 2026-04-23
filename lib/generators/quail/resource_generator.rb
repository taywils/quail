# frozen_string_literal: true

require "rails/generators/base"

module Quail
  module Generators
    # Generates a Quail resource file for a given ActiveRecord model.
    class ResourceGenerator < Rails::Generators::NamedBase
      desc "Generate a Quail resource for a model. Usage: rails g quail:resource Article"
      source_root File.expand_path("templates", __dir__)

      class_option :attributes,
                   type: :array,
                   default: [],
                   desc: "Attributes to expose (default: all columns)"

      class_option :skip_mutations,
                   type: :array,
                   default: [],
                   desc: "Mutations to skip: create update delete"

      class_option :skip_queries,
                   type: :array,
                   default: [],
                   desc: "Queries to skip: find list"

      class_option :subscribe_on,
                   type: :array,
                   default: [],
                   desc: "Events to subscribe on: create update delete"

      def create_resource
        template "resource.rb.tt", "app/graphql/resources/#{file_name}_resource.rb"
      end

      private

      def model_class
        class_name.constantize
      rescue NameError
        nil
      end

      def attribute_names
        if options[:attributes].any?
          options[:attributes].map(&:to_sym)
        elsif model_class
          model_class.column_names.map(&:to_sym)
        else
          [:id]
        end
      end

      def association_lines
        return [] unless model_class

        model_class.reflect_on_all_associations.map do |association|
          case association.macro
          when :has_many    then "  has_many :#{association.name}"
          when :has_one     then "  has_one :#{association.name}"
          when :belongs_to  then "  belongs_to :#{association.name}"
          end
        end.compact
      end

      def writable_attribute_names
        attribute_names.reject { |c| %i[id created_at updated_at].include?(c) }
      end

      def skip_mutations_list
        options[:skip_mutations].map { |m| ":#{m}" }.join(", ")
      end

      def subscribe_on_list
        options[:subscribe_on].map { |e| ":#{e}" }.join(", ")
      end
    end
  end
end
