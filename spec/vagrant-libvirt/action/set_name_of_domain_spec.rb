require "spec_helper"

describe VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain do
  before :each do
    @env = EnvironmentHelper.new
  end

  it "builds uniqie domain name" do
    dmn = VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain.new(Object.new, @env)
    first  = dmn.build_domain_name(@env)
    second = dmn.build_domain_name(@env)
    first.should_not eq(second) 
  end
end
