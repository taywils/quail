# frozen_string_literal: true

module Quail
  module Resource
    module MutationBuilder
      # Runtime resolve logic for auto-generated mutations.
      module Resolvers
        def self.create(model, name, subs, gql_context, attrs)
          record = model.new(attrs)
          return { name.to_sym => nil, errors: record.errors.full_messages } unless record.save

          MutationBuilder.trigger_subscription(gql_context, subs, :create, name, record)
          { name.to_sym => record, errors: [] }
        end

        def self.update(model, name, subs, gql_context, params)
          record = model.find_by(id: params[:id])
          return { name.to_sym => nil, errors: ["#{model.name} not found"] } unless record

          unless record.update(params[:attrs].compact)
            return { name.to_sym => nil,
                     errors: record.errors.full_messages }
          end

          MutationBuilder.trigger_subscription(gql_context, subs, :update, name, record)
          { name.to_sym => record, errors: [] }
        end

        def self.delete(model, name, subs, gql_context, id)
          record = model.find_by(id: id)
          return { success: false, errors: ["#{model.name} not found"] } unless record

          snapshot = MutationBuilder.capture_delete_snapshot(subs, record)
          return { success: false, errors: record.errors.full_messages } unless record.destroy

          MutationBuilder.trigger_delete_event(gql_context, name, snapshot)
          { success: true, errors: [] }
        end
      end
    end
  end
end
