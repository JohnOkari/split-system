module Webhooks
  module Mpesa
    class PayoutsController < ActionController::API
      before_action :authenticate_callback!

      def result
        ::Mpesa::RecordPayoutCallback.new.result(request.request_parameters)
        head :ok
      rescue KeyError, ActiveRecord::RecordNotFound
        Rails.logger.warn("Unmatched M-Pesa B2C result callback")
        head :unprocessable_entity
      end

      def timeout
        ::Mpesa::RecordPayoutCallback.new.timeout(request.request_parameters)
        head :ok
      rescue KeyError, ActiveRecord::RecordNotFound
        Rails.logger.warn("Unmatched M-Pesa B2C timeout callback")
        head :unprocessable_entity
      end

      private

      def authenticate_callback!
        supplied = params[:callback_token].to_s
        expected = ::Mpesa::Configuration.new.callback_token
        valid = supplied.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
        head :not_found unless valid
      rescue KeyError, ArgumentError
        head :not_found
      end
    end
  end
end
