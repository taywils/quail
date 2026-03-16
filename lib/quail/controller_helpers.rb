# frozen_string_literal: true

module Quail
  module ControllerHelpers
    extend ActiveSupport::Concern

    private

    def normalize_request_params(request_params)
      case request_params
      when String then request_params.present? ? JSON.parse(request_params) : {}
      when Hash then request_params
      when ActionController::Parameters then request_params.to_unsafe_hash
      when nil then {}
      else raise ArgumentError, "Unexpected parameter: #{request_params}"
      end
    end

    def handle_error_in_development(error)
      logger.error error.message
      logger.error error.backtrace.join("\n")
      render json: { errors: [{ message: error.message, backtrace: error.backtrace }], data: {} }, status: 500
    end
  end
end
