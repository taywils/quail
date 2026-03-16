# frozen_string_literal: true

module Quail
  # ActionCable channel for handling GraphQL subscriptions over WebSocket.
  class Channel < ActionCable::Channel::Base
    def subscribed
      @subscription_ids = []
      result = execute_query
      track_subscription(result)
      transmit(result: result.to_h, more: result.subscription?)
    end

    def unsubscribed
      @subscription_ids&.each do |subscription_id|
        schema_class.subscriptions.delete_subscription(subscription_id)
      end
    end

    private

    def execute_query
      schema_class.execute(
        params[:query],
        context: context_for_subscription,
        variables: ensure_hash(params[:variables]),
        operation_name: params[:operation_name]
      )
    end

    def track_subscription(result)
      @subscription_ids << result.context[:subscription_id] if result.context[:subscription_id]
    end

    def context_for_subscription
      { channel: self }
    end

    def schema_class
      Rails.application.config.quail.schema_class
    end

    def ensure_hash(some_param)
      case some_param
      when String then some_param.present? ? JSON.parse(some_param) : {}
      when Hash then some_param
      when ActionController::Parameters then some_param.to_unsafe_hash
      when nil then {}
      else raise ArgumentError, "Unexpected parameter: #{some_param.class}"
      end
    end
  end
end
