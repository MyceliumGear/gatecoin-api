require 'spec_helper'

describe GatecoinAPI do

  it 'has a version number' do
    expect(GatecoinAPI::VERSION).not_to be nil
  end

  it 'has url constants' do
    expect(GatecoinAPI::TEST_URL).to eq 'https://staging.gatecoin.com'
    expect(GatecoinAPI::PRODUCTION_URL).to eq 'https://gatecoin.com'
  end

  it 'has configuration fields' do
    expect(GatecoinAPI.logger).to eq nil
    GatecoinAPI.logger = 1
    expect(GatecoinAPI.logger).to eq 1

    expect(GatecoinAPI.logger_options).to eq nil
    GatecoinAPI.logger_options = 2
    expect(GatecoinAPI.logger_options).to eq 2
  end
end
