require 'spec_helper'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

describe Bosh::AzureCloud::AzureClient2 do
  let(:logger) { Bosh::Clouds::Config.logger }

  describe "#http_get_response_with_retry" do
    let(:http_handler) { double("http") }
    let(:request) { double("request") }
    let(:response) { double("response") }
    let(:azure_client2) {
      Bosh::AzureCloud::AzureClient2.new(
        mock_azure_properties,
        logger
      )
    }

    context "when network errors happen" do
      [
        Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, EOFError,
        OpenSSL::SSL::SSLError.new(ERROR_MSG_OPENSSL_RESET), OpenSSL::X509::StoreError.new(ERROR_MSG_OPENSSL_RESET), 
        StandardError.new('Hostname not known'), StandardError.new('Connection refused - connect(2) for \"xx.xxx.xxx.xx\" port 443'),
      ].each do |error|
        context "when #{error} is raised" do
          before do
            allow(http_handler).to receive(:request).with(request).and_raise(error)
          end

          it "should retry for #{AZURE_MAX_RETRY_COUNT} times and fail finally" do
            expect(azure_client2).to receive(:sleep).with(5).exactly(AZURE_MAX_RETRY_COUNT).times
            expect {
              azure_client2.send(:http_get_response_with_retry, http_handler, request)
            }.to raise_error(error)
          end
        end

        context "when #{error} is raised at the first time but returns 200 at the second time" do
          before do
            times_called = 0
            allow(http_handler).to receive(:request).with(request) do
              times_called += 1
              raise error if times_called == 1 # raise error 1 time
              response
            end
          end

          it "should retry for 1 time and get response finally" do
            expect(azure_client2).to receive(:sleep).with(5).once
            expect(
              azure_client2.send(:http_get_response_with_retry, http_handler, request)
            ).to be(response)
          end
        end
      end

      #context "when OpenSSL::SSL::SSLError without specified message 'SSL_connect' is raised" do
      #  before do
      #    stub_request(:post, token_uri).
      #      to_raise(OpenSSL::SSL::SSLError.new)
      #  end

      #  it "should raise OpenSSL::SSL::SSLError" do
      #    expect {
      #      azure_client2.get_resource_by_id(url, { 'api-version' => api_version })
      #    }.to raise_error OpenSSL::SSL::SSLError
      #  end
      #end

      #context "when OpenSSL::X509::StoreError without specified message 'SSL_connect' is raised" do
      #  before do
      #    stub_request(:post, token_uri).
      #      to_raise(OpenSSL::X509::StoreError.new)
      #  end

      #  it "should raise OpenSSL::X509::StoreError" do
      #    expect {
      #      azure_client2.get_resource_by_id(url, { 'api-version' => api_version })
      #    }.to raise_error OpenSSL::X509::StoreError
      #  end
      #end
    end
  end
end
