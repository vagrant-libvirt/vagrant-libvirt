# frozen_string_literal: true

require 'spec_helper'

require 'vagrant-libvirt/action/halt_domain'

describe VagrantPlugins::ProviderLibvirt::Action::HaltDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:driver) { double('driver') }
  let(:libvirt_domain) { double('libvirt_domain') }
  let(:servers) { double('servers') }

  before do
    allow(machine.provider).to receive('driver').and_return(driver)
    allow(driver).to receive(:created?).and_return(true)
    allow(driver).to receive(:connection).and_return(connection)
  end

  describe '#call' do
    before do
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      allow(ui).to receive(:info).with('Halting domain...')
    end

    context "when state is not running" do
      before { expect(driver).to receive(:state).at_least(1).
          and_return(:not_created) }

      it "should not poweroff when state is not running" do
        expect(domain).not_to receive(:poweroff)
        subject.call(env)
      end

      it "should not print halting message" do
        expect(ui).not_to receive(:info)
        subject.call(env)
      end
    end

    context "when state is running" do
      before do
        expect(driver).to receive(:state).and_return(:running)
      end

      it "should poweroff" do
        expect(domain).to receive(:poweroff)
        subject.call(env)
      end

      it "should print halting message" do
        allow(domain).to receive(:poweroff)
        expect(ui).to receive(:info).with('Halting domain...')
        subject.call(env)
      end
    end
  end
end
