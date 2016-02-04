require 'base64'
require 'openssl'
require 'multi_json'
require 'faraday'

# https://staging.gatecoin.com/api/swagger-ui/index.html
module GatecoinAPI
  class Client

    InvalidCredentials = Class.new(ArgumentError)

    class ApiError < StandardError

      attr_reader :raw, :errors

      def initialize(message, code, raw)
        @raw    = raw
        @errors = @raw['errors']
        super "#{message} [#{code}]"
      end
    end

    attr_accessor :public_key, :private_key, :url

    def initialize(public_key:, private_key:, url: GatecoinAPI::TEST_URL, password: nil)
      @public_key  = public_key
      @private_key = private_key
      @url         = url
      @password = password
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

      result = parse_response(response)

      self.class.new(
        public_key: result['publicKey'],
        private_key: result['apiKey'],
        password: password,
        url: url
      )
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

      result = parse_response(response)

      self.class.new(
        public_key: result['publicKey'],
        private_key: result['apiKey'],
        password: password,
        url: url
      )
    end

    def update_user_information(personal_information: {}, resident_information: {})
      params = {
        GivenName: personal_information[:given_name],
        FamilyName: personal_information[:family_name],
        Citiznship: personal_information[:nationality],
        Line1: resident_information[:address],
        City: resident_information[:city],
        State: resident_information[:state],
        ZIP: resident_information[:zip],
        CountryCode: resident_information[:country_code],
        Password: @password
      }.select{|_,v| v}

      birthday = personal_information[:birthday]
      if birthday && (birthday != '')
        params.merge!(Birthday: Date.parse(birthday).to_time.to_i)
      end

      response = connection(sign: true).put('/api/Account/User') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def user_information
      response = connection(sign: true).get('/api/Account/User')

      result = parse_response(response)["info"]

      {
        personal_information: {
          given_name: result['givenName'],
          family_name: result['familyName'],
          nationality: result['citizenship']
        },
        resident_information: {
          address: result['line1'],
          city: result['city'],
          state: result['state'],
          country_code: result['countryCode'],
          zip: result['zip']
        }
      }
    end

    def update_personal_information(given_name:, family_name:, birthday:, nationality:)
      params = {
        GivenName:   given_name,
        FamilyName:  family_name,
        Birthday:    birthday,
        Nationality: nationality,
      }

      response = connection(sign: true).put('/api/Account/PersonalInformation') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def personal_information
      response = connection(sign: true).get('/api/Account/PersonalInformation')

      result = parse_response(response)['personalInfo']

      {
        given_name: result['givenName'],
        family_name: result['familyName'],
        nationality: result['nationality']
      }
    end

    def update_resident_information(address:, city:, state:, zip:, home_phone: nil, mobile_phone: nil, country_code: nil)
      params               = {
        Line1: address,
        City:  city,
        State: state,
        ZIP:   zip,
      }
      params[:HomePhone]   = home_phone if home_phone
      params[:MobilePhone] = mobile_phone if mobile_phone
      params[:CountryCode] = country_code if country_code

      response = connection(sign: true).put('/api/Account/ResidentInformation') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def resident_information
      response = connection(sign: true).get('/api/Account/ResidentInformation')

      result = parse_response(response)['residentInfo']

      {
        address: result['line1'],
        city: result['city'],
        state: result['state'],
        zip: result['zip'],
        country_code: result['countryCode']
      }
    end

    def update_document_information(id_number:, id_issuing_country:, id_content: nil, address_proof_content: nil, id_mime_type: 'image/jpeg', address_proof_mime_type: 'image/jpeg')
      params = {
        IDDocumentNumber: id_number,
        IDIssuingCountry: id_issuing_country
      }

      if id_content
        params[:IDContent] = Base64.strict_encode64(id_content)
        params[:IDMimeType] = id_mime_type
      end

      if address_proof_content
        params[:ProofContent] = Base64.strict_encode64(address_proof_content)
        params[:ProofMimeType] = address_proof_mime_type
      end

      response = connection(sign: true).put('/api/Account/DocumentInformation') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def document_information
      response = connection(sign: true).get('/api/Account/DocumentInformation')

      result = parse_response(response)

      {
        id_status: (result['idStatus'] == 'Present'),
        address_proof_status: (result['proofStatus'] == 'Present')
      }
    end

    def fill_questionnaire(answers)
      params = answers.each_with_object({}) do |(k, v), hash|
        number = k.to_i
        next if number <= 0
        hash[:"Answer#{k.to_s.rjust(3, '0')}"] = v
      end

      response = connection(sign: true).post('/api/Account/Questionnaire') do |req|
        req.body = MultiJson.dump(params)
      end

      parse_response(response)
    end

    def questionnaire
      response = connection(sign: true).get('/api/Account/Questionnaire')

      parse_response(response)
    end

    # def request_verification(level: 4)
    #   params = {
    #     Level: level,
    #   }
    #
    #   response = connection(sign: true).post('/api/Account/Level') do |req|
    #     req.body = MultiJson.dump(params)
    #   end
    #
    #   parse_response(response)
    # end

    def verification_level
      response = connection(sign: true).get('/api/Account/Level')
      result   = parse_response(response)
      level    = result['level']

      {level: level, description: VERIFICATION_LEVELS[level], response: result}
    end

    # fails if verification level < 4
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
