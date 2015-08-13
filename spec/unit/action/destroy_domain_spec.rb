require "spec_helper"
require "support/sharedcontext"
require "support/libvirt_context"

require "vagrant-libvirt/action/destroy_domain"

describe VagrantPlugins::ProviderLibvirt::Action::DestroyDomain do

  subject { described_class.new(app, env) }

  include_context "unit"
  include_context "libvirt"

  let(:libvirt_domain) { double("libvirt_domain") }
  let(:libvirt_client) { double("libvirt_client") }
  let(:servers) { double("servers") }

  describe "#call" do
    before do
      allow_any_instance_of(VagrantPlugins::ProviderLibvirt::Driver).
        to receive(:connection).and_return(connection)
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid).
        and_return(libvirt_domain)
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)
      # always see this at the start of #call
      expect(ui).to receive(:info).with("Removing domain...")
    end

    context "when no snapshots" do
      let(:root_disk) { double("libvirt_root_disk") }

      before do
        allow(libvirt_domain).to receive(:list_snapshots).and_return([])
        allow(libvirt_domain).to receive(:has_managed_save?).and_return(nil)
        root_disk.stub(:name => "test.img")
      end

      context "when only has root disk" do
        it "calls fog to destroy volumes" do
          expect(domain).to receive(:destroy).with(:destroy_volumes => true)
          expect(subject.call(env)).to be_nil
        end
      end

      context "when has additional disks" do
        let(:vagrantfile) { <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
            config.vm.provider :libvirt do |libvirt|
              libvirt.storage :file
            end
          end
          EOF
        }

        let(:extra_disk) { double("libvirt_extra_disk") }
        before do
          extra_disk.stub(:name => "test-vdb.qcow2")
        end

        it "destroys disks individually" do
          allow(libvirt_domain).to receive(:name).and_return("test")
          allow(domain).to receive(:volumes).and_return([extra_disk], [root_disk])

          expect(domain).to receive(:destroy).with(:destroy_volumes => false)
          expect(extra_disk).to receive(:destroy)  # extra disk remove
          expect(root_disk).to receive(:destroy)  # root disk remove
          expect(subject.call(env)).to be_nil
        end
      end

      context "when has CDROMs attached" do
        let(:vagrantfile) { <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
            config.vm.provider :libvirt do |libvirt|
              libvirt.storage :file, :device => :cdrom
            end
          end
          EOF
        }

        it "uses explicit removal of disks" do
          allow(libvirt_domain).to receive(:name).and_return("test")
          allow(domain).to receive(:volumes).and_return([root_disk])

          expect(domain).to_not receive(:destroy).with(:destroy_volumes => true)
          expect(root_disk).to receive(:destroy)  # root disk remove
          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
