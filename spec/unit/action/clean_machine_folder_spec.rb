require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/action/clean_machine_folder'

describe VagrantPlugins::ProviderLibvirt::Action::CleanMachineFolder do
  subject { described_class.new(app, env) }

  include_context 'unit'

  describe '#call' do
    context 'with default options' do
      it 'should verbosely remove the folder' do
        expect(ui).to receive(:info).with('Deleting the machine folder')
        expect(FileUtils).to receive(:rm_rf).with(machine.data_dir, {:secure => true})

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when the data dir doesn\'t exist' do
      before do
        Dir.mktmpdir do |d|
          # returns a temporary directory that has been already deleted when running
          expect(machine).to receive(:data_dir).and_return(d.to_s).exactly(2).times
        end
      end

      it 'should remove the folder' do
        expect(ui).to receive(:info).with('Deleting the machine folder')
        expect(FileUtils).to receive(:rm_rf).with(machine.data_dir, {:secure => true})

        expect(subject.call(env)).to be_nil
      end
    end

    context 'with quiet option enabled' do
      subject { described_class.new(app, env, {:quiet => true}) }

      it 'should quietly remove the folder' do
        expect(ui).to_not receive(:info).with('Deleting the machine folder')
        expect(FileUtils).to receive(:rm_rf).with(machine.data_dir, {:secure => true})

        expect(subject.call(env)).to be_nil
      end
    end
  end
end
