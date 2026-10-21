module Mpesa
  class Configuration
    def initialize
      @credentials = Rails.application.credentials.fetch(:mpesa, {})
    end

    def fetch(key, default = nil)
      env_key = "MPESA_#{key.to_s.upcase}"
      value = ENV[env_key]
      value = @credentials[key] if value.nil?
      value.nil? ? default : value
    end

    def environment
      fetch(:environment, "sandbox").to_s
    end

    def production?
      environment == "production"
    end

    def enabled_for_payouts?
      fetch(:b2c_enabled, "false").to_s == "true"
    end

    def funding_available?
      fetch(:funding_available, "false").to_s == "true"
    end

    def recipient_phone
      value = fetch(:recipient_phone).to_s
      raise KeyError, "Missing M-Pesa recipient phone configuration" if value.blank?
      raise ArgumentError, "Recipient phone must use 254XXXXXXXXX format" unless value.match?(/\A254[17]\d{8}\z/)

      value
    end

    def callback_url(kind)
      ENV.fetch("MPESA_B2C_#{kind.to_s.upcase}_URL")
    end

    def callback_token
      token = fetch(:callback_token).to_s
      raise KeyError, "Missing MPESA_CALLBACK_TOKEN" if token.blank?
      raise ArgumentError, "MPESA_CALLBACK_TOKEN must be at least 32 characters" if token.length < 32

      token
    end
  end
end
