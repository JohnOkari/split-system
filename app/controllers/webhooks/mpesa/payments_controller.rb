module Webhooks
  module Mpesa
    class PaymentsController < ActionController::API
      before_action :authenticate_callback!

      def confirmation
        event = ::Mpesa::RecordConfirmation.new.call(request.request_parameters)
        ::MpesaOutboxDispatchJob.perform_later if event.processing_status == "processed"
        render json: { ResultCode: 0, ResultDesc: "Accepted" }, status: :ok
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
