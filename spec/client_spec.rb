require 'gatecoin-api'

RSpec.describe GatecoinAPI::Client do

  # before :all do
  #   require 'logger'
  #   GatecoinAPI.logger = ::Logger.new(STDOUT)
  #   GatecoinAPI.logger_options = {bodies: true}
  # end

  it "is initializable" do
    expect {
      described_class.new
    }.to raise_error(ArgumentError)

    @client = described_class.new(public_key: '2', private_key: '3')
    expect(@client.public_key).to eq '2'
    expect(@client.private_key).to eq '3'
    expect(@client.url).to eq 'https://staging.gatecoin.com'

    @client = described_class.new(public_key: '2', private_key: '3', url: 'http://example.com')
    expect(@client.public_key).to eq '2'
    expect(@client.private_key).to eq '3'
    expect(@client.url).to eq 'http://example.com'
  end

  it "constructs connection" do
    @client     = described_class.new(public_key: '2', private_key: '3')
    @connection = @client.connection
    expect(@connection.url_prefix.to_s).to eq GatecoinAPI::TEST_URL + '/'
    expect(@connection.headers).to eq('Content-Type' => 'application/json', 'User-Agent' => 'Faraday v0.9.2')
  end

  it "constructs signed connection" do
    @client = described_class.new(public_key: '2', private_key: nil)
    expect {
      @connection = @client.connection(sign: true)
    }.to raise_error(described_class::InvalidCredentials)

    @client = described_class.new(public_key: nil, private_key: '3')
    expect {
      @connection = @client.connection(sign: true)
    }.to raise_error(described_class::InvalidCredentials)

    @client     = described_class.new(public_key: '2', private_key: '3')
    @connection = @client.connection(sign: true)
  end

  describe "API wrapper" do

    EMAIL         = 'alerticus+gatecoin.test@gmail.com'
    PASSWORD      = '123123123'
    REFERRAL_CODE = 'VIUNSL'
    LOGIN         = {username: EMAIL, password: PASSWORD}
    PASSWORD2     = 'GtcP@ssw0rd'

    it "does not allows requests" do
      expect {
        described_class.new(public_key: 'a', private_key: 'b').connection.get('/')
      }.to raise_error(VCR::Errors::UnhandledHTTPRequestError)
    end

    context "basic API key" do

      before :each do
        @client = described_class.new(
          public_key:  'Bc8X6lIxZdPnYJNfatPpLiX1oDwxNOvt',
          private_key: '7357677AA0B274BB6B422790F30DC4C6',
        )
      end

      it "registers user" do
        details = {
          email:         EMAIL,
          password:      PASSWORD,
          referral_code: REFERRAL_CODE,
        }
        VCR.use_cassette 'gatecoin_register_user' do
          @result = @client.register_user(**details)
        end
        expect(@result).to eq("isSuccess" => true, "apiKey" => "D645422FAB05830D2AE31569F78FE085", "publicKey" => "EoDwBHz1wWZlgiR51Us7p0Ilkx9p9K8M", "alias" => "IVI871", "defaultCurrency" => "BTCUSD", "defaultLanguage" => "en", "verifLevel" => 1, "userHasUnreadTickets" => false, "lastLogonTime" => "1447756076", "isPendingUnlockSecret" => false, "responseStatus" => {"message" => "OK"})
      end

      it "authenticates user by email and password" do
        VCR.use_cassette 'gatecoin_auth_user_by_email_and_password' do
          @result = @client.login(**LOGIN)
        end
        expect(@result[1]).to eq("isSuccess" => true, "apiKey" => "5B10460808B26D170B83AE2982B47F11", "publicKey" => "jsuhiFsS05xqSk3pMH2HzqlgXXPWm9Um", "alias" => "IVI871", "defaultCurrency" => "BTCUSD", "defaultLanguage" => "en", "verifLevel" => 1, "userHasUnreadTickets" => false, "lastLogonTime" => "1448018985", "isPendingUnlockSecret" => false, "responseStatus" => {"message" => "OK"})
        expect(@result[0]).to be_instance_of described_class
        expect(@result[0].public_key).to eq 'jsuhiFsS05xqSk3pMH2HzqlgXXPWm9Um'
        expect(@result[0].private_key).to eq '5B10460808B26D170B83AE2982B47F11'
      end

      context "short-term API key" do

        it "uploads DocumentID" do
          details = {
            number:  '007',
            country: 'AT',
            content: File.read(File.expand_path('../fixtures/multipass.jpg', __FILE__)),
          }
          VCR.use_cassette 'gatecoin_post_document_id' do
            @new_client, = @client.login(**LOGIN)
            @result      = @new_client.post_document_id(**details)
          end
          expect(@result).to eq("responseStatus" => {"message" => "OK"})
        end

        it "uploads DocumentAddress" do
          details = {
            content: File.read(File.expand_path('../fixtures/multipass.jpg', __FILE__)),
          }
          VCR.use_cassette 'gatecoin_post_document_address' do
            @new_client, = @client.login(**LOGIN)
            @result      = @new_client.post_document_address(**details)
          end
          expect(@result).to eq("responseStatus" => {"message" => "OK"})
        end

        it "gets documents status" do
          VCR.use_cassette 'gatecoin_documents_status' do
            @new_client, = @client.login(**LOGIN)
            @result      = @new_client.documents_status
          end
          expect(@result).to eq("DocumentID" => "Present", "DocumentAddress" => "Present")
        end
      end

      it "links bank account" do
        details = {
          bank_name:      'TestBank',
          label:          'Test',
          account_number: 'AT131490022010010999',
          currency:       'USD',
          holder_name:    'Tester',
          city:           'Vienna',
          country_code:   'AT',
          password:       PASSWORD2,
        }
        VCR.use_cassette 'gatecoin_link_bank_account' do
          @result = @client.link_bank_account(**details)
        end
        expect(@result).to eq("responseStatus" => {"message" => "OK"})
      end

      it "gets bank accounts" do
        VCR.use_cassette 'gatecoin_bank_accounts' do
          @result = @client.bank_accounts
        end
        expect(@result).to eq("withdrawalLimits" => [{"currency" => "USD", "limit" => 100000.0, "minimum" => 100.0}], "totalWithdrawns" => [{"currency" => "USD", "total" => 0}], "accounts" => [{"bankName" => "TestBank", "label" => "Test", "accountNumber" => "AT131490022010010999", "currency" => "USD", "holderName" => "Tester", "city" => "Vienna", "country" => "AT"}], "responseStatus" => {"message" => "OK"})
      end
    end

    context "allowTrade API key" do

      before :each do
        @client = described_class.new(
          public_key:  'YQqrQFHk6UcLYCkz4HTmaJTMKH0VWgCA',
          private_key: '0885DC35264C5D159EC911096DC36074',
        )
      end

      it "updates gateway settings" do
        details = {
          expiry_second: 1800,
          webhook:       'http://127.0.0.1/test',
        }
        VCR.use_cassette 'gatecoin_update_gateway' do
          @result = @client.update_gateway(**details)
        end
        expect(@result).to eq("responseStatus" => {"message" => "OK"})
      end

      it "gets gateways" do
        VCR.use_cassette 'gatecoin_gateways' do
          @result = @client.gateways
        end
        expect(@result).to eq("gateways" => [{"label" => "Payment", "minConfirmation" => 6, "expirySecond" => 1800, "webhook" => "http://127.0.0.1/test"}], "responseStatus" => {"message" => "OK"})
      end

      it "gets payments" do
        VCR.use_cassette 'gatecoin_payments' do
          @result = @client.payments
        end
        expect(@result).to eq("payments" => [{"txID" => "f3bc9bc5-4eb2-4083-8309-f8cfd7d95916", "amount" => 0.00895413, "amountReceived" => 0.0, "status" => "New", "confirmation" => 0, "createDate" => "1448457033", "expiryDate" => "1448458833", "reference" => "hashed_order_id_1"}, {"txID" => "f6ca47c4-db81-478a-bd69-187409511d51", "amount" => 0.00358165, "amountReceived" => 0.0, "status" => "Expired", "confirmation" => 0, "createDate" => "1448455916", "expiryDate" => "1448455976", "reference" => "hashed_order_id_1"}, {"txID" => "2c168a1b-9364-46d1-a28a-efa66c6f0ad8", "amount" => 0.00358165, "amountReceived" => 0.0, "status" => "Expired", "confirmation" => 0, "createDate" => "1447295477", "expiryDate" => "1447295537"}], "responseStatus" => {"message" => "OK"})
      end

      it "creates quote for fiat" do
        details = {
          currency_to: 'USD',
          amount:      2.5,
          reference:   'hashed_order_id_1',
        }
        VCR.use_cassette 'gatecoin_create_quote_USD' do
          @result = @client.create_quote(**details)
        end
        expect(@result).to eq("address" => "mhdyqC2VEEsa6ekqNRX2Mhb1g9oPtMZFJa", "price" => 0.00358165, "amount" => 0.008954125, "txID" => "a3f0b2c3-2c4a-4751-a03a-1ad903622e44", "responseStatus" => {"message" => "OK"})
      end
    end
  end

  describe "signing middleware" do

    it "creates signature" do
      env = {
        method:          'GET',
        url:             'https://staging.gatecoin.com/api/Account/Address',
        request_headers: {
          :content_type      => 'application/json',
          'API_REQUEST_DATE' => '1447699895.781',
        },
      }
      expect(GatecoinAPI::Client::SigningMiddleware.new(nil, 'Bc8X6lIxZdPnYJNfatPpLiX1oDwxNOvt', '7357677AA0B274BB6B422790F30DC4C6').signature(env)).to eq 'yDnHrh1u7peFRMVDiAEAKbQguocBJNK8nUqD11yLMBI='
    end
  end
end
