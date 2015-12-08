require 'base64'
require 'openssl'
require 'multi_json'
require 'faraday'

# https://staging.gatecoin.com/api/swagger-ui/index.html
module GatecoinAPI
  class Client

    InvalidCredentials = Class.new(ArgumentError)

    class ApiError < StandardError

      attr_reader :raw

      def initialize(message, code, raw)
        @raw = raw
        super "#{message} [#{code}]"
      end
    end

    attr_accessor :public_key, :private_key, :url

    def initialize(public_key:, private_key:, url: GatecoinAPI::TEST_URL)
      @public_key  = public_key
      @private_key = private_key
      @url         = url
    end

    def register_user(email:, password:, is_corporate_account: false, language: 'en', referral_code: nil)
      params                = {
        Email:              email,
        Password:           password,
        IsCorporateAccount: is_corporate_account,
        language:           language,
      }
      params[:ReferralCode] = referral_code if referral_code

      response = connection(sign: true).post('/api/RegisterUser') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def login(username:, password:, validation_code: nil)
      params                  = {
        UserName: username,
        Password: password,
      }
      params[:ValidationCode] = validation_code if validation_code

      response = connection(sign: true).post('/api/Auth/Login') do |req|
        req.body = MultiJson.dump(params)
      end
      result   = parse_response(response)
      client   = self.class.new(public_key: result['publicKey'], private_key: result['apiKey'], url: url)

      [client, result]
    end

    def post_document_id(number:, country:, content:, mime_type: 'image/jpeg')
      params = {
        DocumentNumber: number,
        IssuingCountry: country,
        Content:        Base64.strict_encode64(content),
        MimeType:       mime_type,
      }

      response = connection(sign: true).post('/api/Account/DocumentID') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def post_document_address(content:, mime_type: 'image/jpeg')
      params = {
        Content:  Base64.strict_encode64(content),
        MimeType: mime_type,
      }

      response = connection(sign: true).post('/api/Account/DocumentAddress') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def documents_status
      result = {}

      response             = connection(sign: true).get('/api/Account/DocumentID')
      parsed               = parse_response(response)
      result['DocumentID'] = parsed['status']

      response                  = connection(sign: true).get('/api/Account/DocumentAddress')
      parsed                    = parse_response(response)
      result['DocumentAddress'] = parsed['status']

      result
    end

    # fails unless documents are verified
    def link_bank_account(bank_name:, label:, account_number:, currency:, holder_name:, city:, country_code:, password:,
                          swift_code: nil, bank_code: nil, branch_name: nil, bank_address: nil, bank_phone: nil, validation_code: nil)
      params                  = {
        BankName:      bank_name,
        Label:         label,
        AccountNumber: account_number,
        Currency:      currency,
        HolderName:    holder_name,
        City:          city,
        CountryCode:   country_code,
        Password:      password,
      }
      params[:SwiftCode]      = swift_code if swift_code
      params[:BankCode]       = bank_code if bank_code
      params[:BranchName]     = branch_name if branch_name
      params[:Address]        = bank_address if bank_address
      params[:Phone]          = bank_phone if bank_phone
      params[:ValidationCode] = validation_code if validation_code

      response = connection(sign: true).post('/api/Bank/UserAccounts') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def bank_accounts
      response = connection(sign: true).get('/api/Bank/UserAccounts')

      parse_response(response)
    end

    def create_quote(currency_to:, amount:, is_amount_in_currency_from: false, reference: nil, label: nil)
      params             = {
        CurrencyTo:             currency_to,
        Amount:                 amount,
        IsAmountInCurrencyFrom: is_amount_in_currency_from,
      }
      params[:Reference] = reference if reference
      params[:Label]     = label if label

      response = connection(sign: true).post('/api/Merchant/Payment/Quote') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def update_gateway(expiry_second: nil, webhook: nil)
      params                = {}
      params[:Webhook]      = webhook if webhook
      params[:ExpirySecond] = expiry_second if expiry_second

      response = connection(sign: true).put('/api/Merchant/Gateway') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def gateways
      response = connection(sign: true).get('/api/Merchant/Gateway')

      parse_response(response)
    end

    def payments
      response = connection(sign: true).get('/api/Merchant/Payment')

      parse_response(response)
    end


    def parse_response(response)
      result = MultiJson.load(response.body)
      if (status = result['responseStatus']) && (error_code = status['errorCode'])
        fail ApiError.new(status['message'], error_code, status)
      end
      result
    end

    def connection(sign: false)
      Faraday.new(connection_options) do |faraday|
        if sign
          raise InvalidCredentials unless @public_key && @private_key
          faraday.use SigningMiddleware, @public_key, @private_key
        end
        faraday.response(:logger, GatecoinAPI.logger, GatecoinAPI.logger_options || {}) if GatecoinAPI.logger
        faraday.adapter :net_http
      end
    end

    private def connection_options
      {
        url:     @url,
        ssl:     {
          ca_path: ENV['SSL_CERT_DIR'] || '/etc/ssl/certs',
        },
        headers: {
          content_type: 'application/json',
        },
      }
    end

    class CaseSensitiveString < String
      def downcase
        self
      end

      def upcase
        self
      end

      def capitalize
        self
      end
    end

    class SigningMiddleware < Faraday::Middleware

      API_PUBLIC_KEY        = CaseSensitiveString.new('API_PUBLIC_KEY').freeze
      API_REQUEST_DATE      = CaseSensitiveString.new('API_REQUEST_DATE').freeze
      API_REQUEST_SIGNATURE = CaseSensitiveString.new('API_REQUEST_SIGNATURE').freeze

      def initialize(app, public_key, private_key)
        @app         = app
        @public_key  = public_key
        @private_key = private_key
      end

      def call(env)
        env[:request_headers][API_PUBLIC_KEY]        = @public_key
        env[:request_headers][API_REQUEST_DATE]      = Time.now.to_f.round(3).to_s
        env[:request_headers][API_REQUEST_SIGNATURE] = signature(env)
        @app.call(env)
      end

      # Base64Encode(
      #   HMAC-SHA256(
      #     (“POST" + "https://staging.gatecoin.com/api/RegisterUser” +
      #      "application/json" + "1447700841.477091").downcase,
      #     @private_key
      #   )
      # )
      def signature(env)
        http_method  = env[:method].to_s.upcase
        content_type = http_method == 'GET' ? '' : env[:request_headers][:content_type]
        message      = "#{http_method}#{env[:url]}#{content_type}#{env[:request_headers][API_REQUEST_DATE]}".downcase
        Base64.strict_encode64 OpenSSL::HMAC.digest('sha256', @private_key, message)
      end
    end
  end
end
