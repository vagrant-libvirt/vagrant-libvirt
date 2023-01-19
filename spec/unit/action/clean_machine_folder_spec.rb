# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/action/clean_machine_folder'

describe VagrantPlugins::ProviderLibvirt::Action::CleanMachineFolder do
  subject { described_class.new(app, env) }

  include_context 'unit'

  describe '#call' do
    before do
      FileUtils.touch(File.join(machine.data_dir, "box.meta"))
    end

    context 'with default options' do
      it 'should verbosely remove the folder' do
        expect(ui).to receive(:info).with('Deleting the machine folder')

        expect(subject.call(env)).to be_nil

        expect(File.exist?(machine.data_dir)).to eq(true)
        expect(Dir.entries(machine.data_dir)).to match_array([".", ".."])
      end
    end

    context 'when the data dir doesn\'t exist' do
      before do
        Dir.mktmpdir do |d|
          # returns a temporary directory that has been already deleted when running
          expect(machine).to receive(:data_dir).and_return(d.to_s).exactly(3).times
        end
      end

      it 'should remove the folder' do
        expect(ui).to receive(:info).with('Deleting the machine folder')

        expect(subject.call(env)).to be_nil

        expect(File.exist?(machine.data_dir)).to eq(true)
        expect(Dir.entries(machine.data_dir)).to match_array([".", ".."])
      end
    end

    context 'with quiet option enabled' do
      subject { described_class.new(app, env, {:quiet => true}) }

      it 'should quietly remove the folder' do
        expect(ui).to_not receive(:info).with('Deleting the machine folder')

        expect(subject.call(env)).to be_nil

        expect(File.exist?(machine.data_dir)).to eq(true)
        expect(Dir.entries(machine.data_dir)).to match_array([".", ".."])
      end
    end
  end
end
