# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/cap/synced_folder_9p'

describe VagrantPlugins::SyncedFolder9P::SyncedFolder do
  include_context 'unit'
  include_context 'libvirt'

  subject { described_class.new }

  describe '#usable?' do
    context 'with libvirt provider' do
      before do
        allow(machine).to receive(:provider_name).and_return(:libvirt)
        allow(libvirt_client).to receive(:libversion).and_return(8002000)
      end

      it 'should be' do
        expect(subject).to be_usable(machine)
      end

      context 'with version less than 1.2.2' do
        before do
          allow(libvirt_client).to receive(:libversion).and_return(1002001)
        end

        it 'should not be' do
          expect(subject).to_not be_usable(machine)
        end
      end
    end

    context 'with other provider' do
      before do
        allow(machine).to receive(:provider_name).and_return(:virtualbox)
      end

      it 'should not be' do
        expect(subject).to_not be_usable(machine)
      end
    end
  end
end
