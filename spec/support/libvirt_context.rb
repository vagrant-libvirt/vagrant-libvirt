# frozen_string_literal: true

require 'fog/libvirt'
require 'fog/libvirt/models/compute/server'
require 'libvirt'

shared_context 'libvirt' do
  include_context 'unit'

  let(:libvirt_context) { true                      }
  let(:id)              { 'dummy-vagrant_dummy'     }
  let(:connection)      { double('connection') }
  let(:driver)          { instance_double(VagrantPlugins::ProviderLibvirt::Driver) }
  let(:domain)          { instance_double(::Fog::Libvirt::Compute::Server) }
  let(:libvirt_client)  { instance_double(::Libvirt::Connect) }
  let(:libvirt_domain)  { instance_double(::Libvirt::Domain) }
  let(:logger)          { double('logger') }

  def connection_result(options = {})
    result = options.fetch(:result, nil)
    double('connection_result' => result)
  end

  before (:each) do
    # we don't want unit tests to ever run commands on the system; so we wire
    # in a double to ensure any unexpected messages raise exceptions
    stub_const('::Fog::Compute', connection)

    # drivers also call vm_exists? during init;
    allow(connection).to receive(:servers)
      .and_return(connection_result(result: nil))

    allow(connection).to receive(:client).and_return(libvirt_client)

    allow(machine).to receive(:id).and_return(id)
    allow(Log4r::Logger).to receive(:new).and_return(logger)

    allow(machine.provider).to receive('driver').and_return(driver)
    allow(driver).to receive(:connection).and_return(connection)
  end
end
