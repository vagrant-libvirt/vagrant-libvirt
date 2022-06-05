# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/action/remove_libvirt_image'

describe VagrantPlugins::ProviderLibvirt::Action::RemoveLibvirtImage do
  subject { described_class.new(app, env) }

  include_context 'unit'

  let(:box) { instance_double(::Vagrant::Box) }

  describe '#call' do
    before do
      env[:box_removed] = box
      allow(ui).to receive(:info)
    end

    context 'when called with libvirt box removed' do
      before do
        expect(box).to receive(:provider).and_return(:libvirt)
      end

      it 'should notify the user about limited removal' do
        expect(ui).to receive(:info).with(/Vagrant-libvirt plugin removed box/)
        expect(subject.call(env)).to be_nil
      end
    end

    context 'when called with any other provider box' do
      before do
        expect(box).to receive(:provider).and_return(:virtualbox)
      end

      it 'call the next middle ware immediately' do
        expect(ui).to_not receive(:info).with(/Vagrant-libvirt plugin removed box/)
        expect(subject.call(env)).to be_nil
      end
    end
  end
end
