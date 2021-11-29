# frozen_string_literal: true

require 'spec_helper'
require 'support/sharedcontext'
require 'support/libvirt_context'

require 'vagrant-libvirt/errors'
require 'vagrant-libvirt/action/forward_ports'

describe VagrantPlugins::ProviderLibvirt::Action::ForwardPorts do
  subject { described_class.new(app, env) }

  include_context 'unit'

  let(:machine_config) { double("machine_config") }
  let(:vm_config) { double("vm_config") }
  let(:provider_config) { double("provider_config") }

  before (:each) do
    allow(machine).to receive(:config).and_return(machine_config)
    allow(machine).to receive(:provider_config).and_return(provider_config)
    allow(machine_config).to receive(:vm).and_return(vm_config)
    allow(vm_config).to receive(:networks).and_return([])
    allow(provider_config).to receive(:forward_ssh_port).and_return(false)
  end

  describe '#call' do
    context 'with none defined' do
      it 'should skip calling forward_ports' do
        expect(subject).to_not receive(:forward_ports)
        expect(subject.call(env)).to be_nil
      end
    end

    context 'with network including one forwarded port' do
      let(:networks) { [
        [:private_network, {:ip=>"10.20.30.40", :protocol=>"tcp", :id=>"6b8175ed-3220-4b63-abaf-0bb8d7cdd723"}],
        [:forwarded_port, port_options],
      ]}

      let(:port_options){ {guest: 80, host: 8080} }

      it 'should compile a single port forward to set up' do
        expect(vm_config).to receive(:networks).and_return(networks)
        expect(ui).to_not receive(:warn)
        expect(subject).to receive(:forward_ports).and_return(nil)

        expect(subject.call(env)).to be_nil

        expect(env[:forwarded_ports]).to eq([networks[1][1]])
      end

      context 'when host port in protected range' do
        let(:port_options){ {guest: 8080, host: 80} }

        it 'should emit a warning' do
          expect(vm_config).to receive(:networks).and_return(networks)
          expect(ui).to receive(:warn).with(include("You are trying to forward to privileged ports"))
          expect(subject).to receive(:forward_ports).and_return(nil)

          expect(subject.call(env)).to be_nil
        end
      end
    end

    context 'when udp protocol is selected' do
      let(:port_options){ {guest: 80, host: 8080, protocol: "udp"} }

      it 'should skip and emit warning' do
        expect(vm_config).to receive(:networks).and_return([[:forwarded_port, port_options]])
        expect(ui).to receive(:warn).with("Forwarding UDP ports is not supported. Ignoring.")
        expect(subject).to_not receive(:forward_ports)

        expect(subject.call(env)).to be_nil
      end
    end

    context 'when default ssh port forward provided' do
      let(:networks){ [
        [:private_network, {:ip=>"10.20.30.40", :protocol=>"tcp", :id=>"6b8175ed-3220-4b63-abaf-0bb8d7cdd723"}],
        [:forwarded_port, {guest: 80, host: 8080}],
        [:forwarded_port, {guest: 22, host: 2222, host_ip: '127.0.0.1', id: 'ssh'}],
      ]}

      context 'with default config' do
        it 'should not forward the ssh port' do
          expect(vm_config).to receive(:networks).and_return(networks)
          expect(subject).to receive(:forward_ports)

          expect(subject.call(env)).to be_nil

          expect(env[:forwarded_ports]).to eq([networks[1][1]])
        end
      end

      context 'with forward_ssh_port enabled' do
        before do
          allow(provider_config).to receive(:forward_ssh_port).and_return(true)
        end

        it 'should forward the port' do
          expect(vm_config).to receive(:networks).and_return(networks)
          expect(subject).to receive(:forward_ports)

          expect(subject.call(env)).to be_nil

          expect(env[:forwarded_ports]).to eq(networks.drop(1).map { |_, opts| opts })
        end
      end
    end
  end

  describe '#forward_ports' do
    let(:pid_dir){ machine.data_dir.join('pids') }

    before (:each) do
      allow(env).to receive(:[]).and_call_original
      allow(machine).to receive(:ssh_info).and_return(
        {
          :host => "localhost",
          :username => "vagrant",
          :port => 22,
          :private_key_path => ["/home/test/.ssh/id_rsa"],
        }
      )
      allow(provider_config).to receive(:proxy_command).and_return(nil)
    end

    context 'with port to forward' do
      let(:port_options){ {guest: 80, host: 8080, guest_ip: "192.168.1.121"} }

      it 'should spawn ssh to setup forwarding' do
        expect(env).to receive(:[]).with(:forwarded_ports).and_return([port_options])
        expect(ui).to receive(:info).with("#{port_options[:guest]} (guest) => #{port_options[:host]} (host) (adapter eth0)")
        expect(subject).to receive(:spawn).with(/ssh -n -o User=vagrant -o Port=22.*-L \*:8080:192.168.1.121:80 -N localhost/, anything).and_return(9999)

        expect(subject.forward_ports(env)).to eq([port_options])

        expect(pid_dir.join('ssh_8080.pid')).to have_file_content("9999")
      end
    end

    context 'with privileged host port' do
      let(:port_options){ {guest: 80, host: 80, guest_ip: "192.168.1.121"} }

      it 'should spawn ssh to setup forwarding' do
        expect(env).to receive(:[]).with(:forwarded_ports).and_return([port_options])
        expect(ui).to receive(:info).with("#{port_options[:guest]} (guest) => #{port_options[:host]} (host) (adapter eth0)")
        expect(ui).to receive(:info).with('Requesting sudo for host port(s) <= 1024')
        expect(subject).to receive(:system).with('sudo -v').and_return(true)
        expect(subject).to receive(:spawn).with(/sudo ssh -n -o User=vagrant -o Port=22.*-L \*:80:192.168.1.121:80 -N localhost/, anything).and_return(10000)

        expect(subject.forward_ports(env)).to eq([port_options])

        expect(pid_dir.join('ssh_80.pid')).to have_file_content("10000")
      end
    end
  end
end

describe VagrantPlugins::ProviderLibvirt::Action::ClearForwardedPorts do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  describe '#call' do
    context 'no forwarded ports' do
      it 'should skip checking if pids are running' do
        expect(subject).to_not receive(:ssh_pid?)
        expect(logger).to receive(:info).with('No ssh pids found')

        expect(subject.call(env)).to be_nil
      end
    end

    context 'multiple forwarded ports' do
      before do
        data_dir = machine.data_dir.join('pids')
        data_dir.mkdir unless data_dir.directory?

        [
          {:port => '8080', :pid => '10001'},
          {:port => '8081', :pid => '10002'},
        ].each do |port_pid|
          File.write(data_dir.to_s + "/ssh_#{port_pid[:port]}.pid", port_pid[:pid])
        end
      end
      it 'should terminate each of the processes' do
        expect(logger).to receive(:info).with(no_args) # don't know how to test translations from vagrant
        expect(subject).to receive(:ssh_pid?).with("10001").and_return(true)
        expect(subject).to receive(:ssh_pid?).with("10002").and_return(true)
        expect(logger).to receive(:debug).with(/Killing pid/).twice()
        expect(logger).to receive(:info).with('Removing ssh pid files')
        expect(subject).to receive(:system).with("kill 10001")
        expect(subject).to receive(:system).with("kill 10002")

        expect(subject.call(env)).to be_nil

        expect(Dir.entries(machine.data_dir.join('pids'))).to match_array(['.', '..'])
      end
    end
  end
end
