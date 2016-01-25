require "vagrant-libvirt/action/wait_till_up"
require "vagrant-libvirt/errors"

require "spec_helper"
require "support/sharedcontext"
require "support/libvirt_context"

describe VagrantPlugins::ProviderLibvirt::Action::WaitTillUp do

  subject { described_class.new(app, env) }

  include_context "vagrant-unit"
  include_context "libvirt"
  include_context "unit"

  describe "#call" do
    context "when machine does not exist" do
      before do
        allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:get_domain).and_return(nil)
        allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).to receive(:state).
          and_return(:not_created)
      end

      it "raises exception" do
        expect(app).to_not receive(:call)
        expect{subject.call(env)}.to raise_error
      end
    end
  end

end
