require "spec_helper"
require "unit/cloud/shared_stuff.rb"

describe Bosh::AzureCloud::Cloud do
  include_context "shared stuff"

  describe "#initialize" do
    context "when there is no proper network access to Azure" do
      before do
        allow(Bosh::AzureCloud::TableManager).to receive(:new).and_raise(Net::OpenTimeout, "execution expired")
      end

      it "raises an exception with a user friendly message" do
        expect {
          cloud
        }.to raise_error(Bosh::Clouds::CloudError, "Please make sure the CPI has proper network access to Azure. #<Net::OpenTimeout: execution expired>")
      end
    end

    context "when /var/vcap/sys/run/azure_cpi exists" do
      let(:cpi_lock_dir) { "/var/vcap/sys/run/azure_cpi" }
      before do
        allow(Dir).to receive(:exists?).with(cpi_lock_dir).and_return(true)
      end

      context "when CPI doesn't need to cleanup locks" do
        before do
          allow(File).to receive(:exists?).with("#{cpi_lock_dir}/#{Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE}").and_return(false)
        end

        it "should not create the cpi lock dir and cleanup the locks" do
          expect(Dir).not_to receive(:mkdir)
          expect(Dir).not_to receive(:glob)
          expect {
            cloud
          }.not_to raise_error
        end
      end

      context "when CPI needs to cleanup locks" do
        before do
          allow(File).to receive(:exists?).with("#{cpi_lock_dir}/#{Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE}").and_return(true)
        end

        it "should not create the cpi lock dir, but should cleanup the locks" do
          expect(Dir).not_to receive(:mkdir)
          expect(Dir).to receive(:glob).and_yield("fake-lock")
          expect(File).to receive(:delete).with("fake-lock")
          expect {
            cloud
          }.not_to raise_error
        end
      end
    end

    context "when /var/vcap/sys/run/azure_cpi and /tmp/azure_cpi doesn't exist" do
      let(:cpi_lock_dir_under_bosh_run_dir) { "/var/vcap/sys/run/azure_cpi" }
      let(:cpi_lock_dir) { "/tmp/azure_cpi" }
      before do
        allow(Dir).to receive(:exists?).with(cpi_lock_dir_under_bosh_run_dir).and_return(false)
        allow(Dir).to receive(:exists?).with(cpi_lock_dir).and_return(false)
      end

      context "when CPI doesn't need to cleanup locks" do
        before do
          allow(File).to receive(:exists?).with("#{cpi_lock_dir}/#{Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE}").and_return(false)
        end

        it "should create the cpi lock dir /tmp/azure_cpi, but not clean the locks" do
          expect(Dir).to receive(:mkdir).with(cpi_lock_dir)
          expect(Dir).not_to receive(:glob)
          expect {
            cloud
          }.not_to raise_error
        end
      end

      context "when CPI needs to cleanup locks" do
        before do
          allow(File).to receive(:exists?).with("#{cpi_lock_dir}/#{Bosh::AzureCloud::Helpers::CPI_LOCK_DELETE}").and_return(true)
        end

        it "should create the cpi lock dir /tmp/azure_cpi and cleanup the locks" do
          expect(Dir).to receive(:mkdir).with(cpi_lock_dir)
          expect(Dir).to receive(:glob).and_yield("fake-lock")
          expect(File).to receive(:delete).with("fake-lock")
          expect {
            cloud
          }.not_to raise_error
        end
      end
    end
  end
end
