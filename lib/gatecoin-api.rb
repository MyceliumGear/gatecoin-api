require 'gatecoin-api/version'
require 'gatecoin-api/constants'
require 'gatecoin-api/client'

module GatecoinAPI
  TEST_URL       = 'https://staging.gatecoin.com'
  PRODUCTION_URL = 'https://gatecoin.com'

  class << self
    attr_accessor :logger, :logger_options # https://github.com/lostisland/faraday/blob/master/lib/faraday/response/logger.rb
  end
end
