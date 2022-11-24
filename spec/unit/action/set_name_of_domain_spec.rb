# frozen_string_literal: true

require_relative '../../spec_helper'

require 'vagrant-libvirt/action/set_name_of_domain'

describe VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain do
  before :each do
    @env = EnvironmentHelper.new
  end

  it 'builds unique domain name' do
    @env.random_hostname = true
    dmn = VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain.new(Object.new, @env)
    first  = dmn.build_domain_name(@env)
    second = dmn.build_domain_name(@env)
    expect(first).to_not eq(second)
  end

  it 'builds simple domain name' do
    @env.default_prefix = 'pre_'
    dmn = VagrantPlugins::ProviderLibvirt::Action::SetNameOfDomain.new(Object.new, @env)
    expect(dmn.build_domain_name(@env)).to eq('pre_')
  end
end
