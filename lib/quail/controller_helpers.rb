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

    def handle_error_in_development(e)
      logger.error e.message
      logger.error e.backtrace.join("\n")
      render json: { errors: [{ message: e.message, backtrace: e.backtrace }], data: {} }, status: 500
    end
  end
end