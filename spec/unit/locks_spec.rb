# frozen_string_literal: true

require 'support/sharedcontext'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/locks'

describe VagrantPlugins::ProviderLibvirt::LockManager do
  include_context "unit"
  include_context "temporary_dir"

  before do
    stub_const "VagrantPlugins::ProviderLibvirt::LOCK_DIR", temp_dir
  end

  describe "#lock" do
    it "does nothing if no block is given" do
      subject.lock
    end

    it "raises exception if locked twice" do
      another = described_class.new

      result = false

      subject.lock do
        begin
          # ensure following has a block otherwise it will skip attempting to lock the file
          another.lock {}
        rescue VagrantPlugins::ProviderLibvirt::Errors::AlreadyLockedError
          result = true
        end
      end

      expect(result).to be_truthy
    end

    context "with local lock" do
      it "should handle multiple threads/processes with retry" do
        t1wait = true
        t1locked = false

        # grab the lock and wait
        t1 = Thread.new do
          locker = described_class.new
          locker.lock("common") do
            t1locked = true
            while t1wait === true
              sleep 0.1
            end
          end
        end

        # wait to ensure first process has the lock
        t2 = Thread.new do
          locker = described_class.new
          while t1locked === false
            sleep 0.1
          end

          locker.lock("common", :retry => true) do
            sleep 0.1
          end
        end

        # let first thread complete
        t1wait = false

        # wait for threads to complete.
        expect {
          Timeout::timeout(2) do
            puts sleep 0.1
            expect(t1.value).to eq(nil)  # result from loop
            expect(t2.value).to eq(0)    # result from sleep
          end
        }.to_not raise_error
      end
    end
  end
end
