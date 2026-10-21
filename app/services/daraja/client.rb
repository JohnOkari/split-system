require "net/http"
require "json"
require "base64"
require "uri"

module Daraja
  class Client
    class Error < StandardError
      attr_reader :http_status, :response_body

      def initialize(message, http_status: nil, response_body: nil)
        super(message)
        @http_status = http_status
        @response_body = response_body
      end
    end

    def initialize(configuration: Mpesa::Configuration.new)
      @config = configuration
      @base_url = @config.production? ? "https://api.safaricom.co.ke" : "https://sandbox.safaricom.co.ke"
    end

    def post(path, payload)
      uri = URI("#{@base_url}#{path}")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = perform(uri, request)
      body = parse_body(response)
      raise Error.new("Daraja request failed", http_status: response.code.to_i, response_body: body) unless response.is_a?(Net::HTTPSuccess)

      body
    end

    private

    def access_token
      key = @config.fetch(:consumer_key)
      secret = @config.fetch(:consumer_secret)
      raise KeyError, "Missing Daraja API credentials" if key.blank? || secret.blank?

      uri = URI("#{@base_url}/oauth/v1/generate")
      uri.query = URI.encode_www_form(grant_type: "client_credentials")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Basic #{Base64.strict_encode64("#{key}:#{secret}")}"
      response = perform(uri, request)
      body = parse_body(response)
      raise Error.new("Daraja OAuth failed", http_status: response.code.to_i) unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Daraja OAuth response omitted access token" if body["access_token"].blank?

      body.fetch("access_token")
    end

    def perform(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      http.write_timeout = 15 if http.respond_to?(:write_timeout=)
      http.request(request)
    end

    def parse_body(response)
      JSON.parse(response.body.presence || "{}")
    rescue JSON::ParserError
      raise Error.new("Daraja returned invalid JSON", http_status: response.code.to_i)
    end
  end
end
