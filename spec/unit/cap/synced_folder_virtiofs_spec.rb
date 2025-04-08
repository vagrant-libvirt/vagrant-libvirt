# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/cap/synced_folder_virtiofs'
require 'vagrant-libvirt/util/unindent'

describe VagrantPlugins::SyncedFolderVirtioFS::SyncedFolder do
  include_context 'unit'
  include_context 'libvirt'

  subject { described_class.new }

  describe '#prepare' do
    let(:synced_folders) { {
      "/vagrant" => {
        :hostpath => '/home/test/default',
        :disabled=>false,
        :guestpath=>'/vagrant',
        :type => :virtiofs,
      },
    } }

    let(:expected_xml) {
      <<-EOF.unindent
      <filesystem type="mount" accessmode="passthrough">
        <driver type="virtiofs"></driver>
        <source dir="/home/test/default"></source>
        <target dir="1ef53e1c9b6a5a0c695c80665331652\"></target>
      </filesystem>
      EOF
    }

    before do
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).and_return(libvirt_domain)
      allow(logger).to receive(:debug)
    end

    it 'should attach device xml' do
      expect(libvirt_domain).to receive(:attach_device).with(expected_xml, 0)

      subject.prepare(machine, synced_folders, {})
    end

    context 'multiple folders' do
      let(:synced_folders) { {
        "/vagrant" => {
          :hostpath => '/home/test/default',
          :disabled=>false,
          :guestpath=>'/vagrant',
          :type => :virtiofs,
        },
        "/custom" => {
          :hostpath => '/home/test/custom',
          :disabled=>false,
          :guestpath=>'/custom',
          :type => :virtiofs,
        },
      } }

      let(:expected_xml) {
        [ <<-XML1.unindent, <<-XML2.unindent ]
        <filesystem type="mount" accessmode="passthrough">
          <driver type="virtiofs"></driver>
          <source dir="/home/test/default"></source>
          <target dir="1ef53e1c9b6a5a0c695c80665331652\"></target>
        </filesystem>
        XML1
        <filesystem type="mount" accessmode="passthrough">
          <driver type="virtiofs"></driver>
          <source dir="/home/test/custom"></source>
          <target dir=\"a2a1a8b6d98be8f790f3c987e006d13\"></target>
        </filesystem>
        XML2
      }

      it 'should attach all device xml' do
        expect(libvirt_domain).to receive(:attach_device).with(expected_xml[0], 0)
        expect(libvirt_domain).to receive(:attach_device).with(expected_xml[1], 0)
        expect(ui).to receive(:info).with(/Configuring virtiofs devices for shared folders/).once

        subject.prepare(machine, synced_folders, {})
      end
    end
  end

  describe '#usable?' do
    context 'with libvirt provider' do
      before do
        allow(machine).to receive(:provider_name).and_return(:libvirt)
        allow(libvirt_client).to receive(:libversion).and_return(8002000)
      end

      it 'should be' do
        expect(subject).to be_usable(machine)
      end

      context 'with version less than 6.2.0' do
        before do
          allow(libvirt_client).to receive(:libversion).and_return(6001000)
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
