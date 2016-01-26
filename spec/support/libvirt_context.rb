require 'fog/libvirt'

shared_context "libvirt" do
  include_context "unit"

  let(:libvirt_context) { true                      }
  let(:id)              { "dummy-vagrant_dummy"     }
  let(:connection)      { double("connection")  }
  let(:domain)          { double("domain") }

  def connection_result(options={})
    result = options.fetch(:result, nil)
    double("connection_result" => result)
  end

  before (:each) do
    # we don't want unit tests to ever run commands on the system; so we wire
    # in a double to ensure any unexpected messages raise exceptions
    stub_const("::Fog::Compute", connection)

    # drivers also call vm_exists? during init;
    allow(connection).to receive(:servers).with(kind_of(String)).
      and_return(connection_result(result: nil))
  end
end
