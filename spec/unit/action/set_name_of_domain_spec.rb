require 'spec_helper'

describe VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain do
  before :each do
    @env = EnvironmentHelper.new
  end

  it 'builds unique domain name' do
    @env.random_hostname = true
    dmn = VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain.new(Object.new, @env)
    first  = dmn.build_domain_name(@env)
    second = dmn.build_domain_name(@env)
    first.should_not eq(second)
  end

  it 'builds simple domain name' do
    @env.default_prefix = 'pre'
    dmn = VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain.new(Object.new, @env)
    dmn.build_domain_name(@env).should eq('pre_')
  end
end
