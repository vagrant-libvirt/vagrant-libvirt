# frozen_string_literal: true

require 'spec_helper'

require 'vagrant-libvirt/action/destroy_domain'

describe VagrantPlugins::ProviderLibvirt::Action::DestroyDomain do
  subject { described_class.new(app, env) }

  include_context 'unit'
  include_context 'libvirt'

  let(:driver) { double('driver') }
  let(:libvirt_domain) { double('libvirt_domain') }
  let(:libvirt_client) { double('libvirt_client') }
  let(:servers) { double('servers') }

  let(:domain_xml) { File.read(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), domain_xml_file)) }

  let(:destroy_method) { double('destroy_method') }

  before do
    allow(machine.provider).to receive('driver').and_return(driver)
    allow(driver).to receive(:connection).and_return(connection)
    allow(logger).to receive(:info)
    allow(domain).to receive(:method).with(:destroy).and_return(destroy_method)
    allow(destroy_method).to receive(:parameters).and_return([[:opt, :options, :flags]])
  end

  describe '#call' do
    before do
      allow(connection).to receive(:client).and_return(libvirt_client)
      allow(libvirt_client).to receive(:lookup_domain_by_uuid)
        .and_return(libvirt_domain)
      allow(libvirt_domain).to receive(:name).and_return('vagrant-test_default')
      allow(connection).to receive(:servers).and_return(servers)
      allow(servers).to receive(:get).and_return(domain)

      # always see this at the start of #call
      expect(ui).to receive(:info).with('Removing domain...')
    end

    context 'when no snapshots' do
      let(:root_disk) { double('libvirt_root_disk') }

      before do
        allow(libvirt_domain).to receive(:list_snapshots).and_return([])
        allow(libvirt_domain).to receive(:has_managed_save?).and_return(nil)
        allow(root_disk).to receive(:name).and_return('vagrant-test_default.img')
      end

      context 'when box only has one root disk' do
        it 'calls fog to destroy volumes' do
          expect(domain).to receive(:destroy).with(destroy_volumes: true, flags: 0)
          expect(subject.call(env)).to be_nil
        end

        context 'when has additional disks' do
          let(:vagrantfile_providerconfig) do
            <<-EOF
                libvirt.storage :file
            EOF
          end
          let(:domain_xml_file) { 'additional_disks_domain.xml' }
          let(:extra_disk) { double('libvirt_extra_disk') }

          before do
            allow(extra_disk).to receive(:name).and_return('vagrant-test_default-vdb.qcow2')
            allow(domain).to receive(:volumes).and_return([root_disk, extra_disk])
            expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
          end

          it 'destroys disks individually' do
            expect(domain).to receive(:destroy).with(destroy_volumes: false, flags: 0)
            expect(extra_disk).to receive(:destroy) # extra disk remove
            expect(root_disk).to receive(:destroy)  # root disk remove
            expect(subject.call(env)).to be_nil
          end
        end
      end

      context 'when box has multiple disks' do
        let(:domain_xml_file) { 'box_multiple_disks.xml' }

        it 'calls fog to destroy volumes' do
          expect(domain).to receive(:destroy).with(destroy_volumes: true, flags: 0)
          expect(subject.call(env)).to be_nil
        end

        context 'when has additional disks' do
          let(:domain_xml_file) { 'box_multiple_disks_and_additional_disks.xml' }
          let(:vagrantfile_providerconfig) do
            <<-EOF
                libvirt.storage :file
                libvirt.storage :file
            EOF
          end
          let(:domain_disks) {[
            [double('box-disk-1'), 'vagrant-test_default.img'],
            [double('box-disk-2'), 'vagrant-test_default_1.img'],
            [double('box-disk-3'), 'vagrant-test_default_2.img'],
            [double('additional-disk-1'), 'vagrant-test_default-vdd.qcow2'],
            [double('additional-disk-2'), 'vagrant-test_default-vde.qcow2'],
          ]}

          before do
            allow(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)
            allow(domain).to receive(:volumes).and_return(domain_disks.map { |a| a.first })
          end

          it 'destroys disks individually' do
            domain_disks.each do |disk, name|
              expect(disk).to receive(:name).and_return(name).at_least(:once)
              expect(disk).to receive(:destroy)
            end
            expect(domain).to receive(:destroy).with(destroy_volumes: false, flags: 0)
            expect(subject.call(env)).to be_nil
          end

          context 'when has disks added via custom virsh commands' do
            let(:domain_xml_file) { 'box_multiple_disks_and_additional_and_custom_disks.xml' }
            let(:domain_disks) {[
              [double('box-disk-1'), 'vagrant-test_default.img'],
              [double('box-disk-2'), 'vagrant-test_default_1.img'],
              [double('box-disk-3'), 'vagrant-test_default_2.img'],
              [double('additional-disk-1'), 'vagrant-test_default-vdd.qcow2'],
              [double('additional-disk-2'), 'vagrant-test_default-vde.qcow2'],
              [double('custom-disk-1'), 'vagrant-test_default-vdf.qcow2'],
            ]}

            it 'only destroys expected disks' do
              expect(ui).to receive(:warn).with(/Unexpected number of volumes detected.*/)
              domain_disks.each do |disk, name|
                expect(disk).to receive(:name).and_return(name).at_least(:once)
                next if disk == domain_disks.last.first
                expect(disk).to receive(:destroy)
              end
              expect(domain).to receive(:destroy).with(destroy_volumes: false, flags: 0)
              expect(subject.call(env)).to be_nil
            end

            context 'without aliases' do
              let(:domain_xml_file) { 'box_multiple_disks_and_additional_and_custom_disks_no_aliases.xml' }

              it 'only destroys expected disks' do
                expect(ui).to receive(:warn).with(/Machine that was originally created without device aliases.*/)
                expect(ui).to receive(:warn).with(/Unexpected number of volumes detected/)
                expect(ui).to receive(:warn).with(/box metadata not available to get volume list during destroy, assuming inferred list/)
                domain_disks.each do |disk, name|
                  expect(disk).to receive(:name).and_return(name).at_least(:once)
                  # ignore box disks 2 and 3 and the last custom disk
                  next if domain_disks.last.first == disk
                  expect(disk).to receive(:destroy)
                end
                expect(domain).to receive(:destroy).with(destroy_volumes: false, flags: 0)
                expect(subject.call(env)).to be_nil
              end

              context 'with box metadata' do
                let(:box) { instance_double(::Vagrant::Box) }
                before do
                  allow(env[:machine]).to receive(:box).and_return(box)
                  allow(box).to receive(:metadata).and_return(Hash[
                    'disks' => [
                      {:name => 'box-disk-1'},
                      {:name => 'box-disk-2'},
                      {:name => 'box-disk-3'},
                    ]
                  ])
                end

                it 'only destroys expected disks' do
                  expect(ui).to receive(:warn).with(/Machine that was originally created without device aliases.*/)
                  expect(ui).to receive(:warn).with(/Unexpected number of volumes detected/)
                  domain_disks.each do |disk, name|
                    expect(disk).to receive(:name).and_return(name).at_least(:once)
                    # ignore box disks 2 and 3 and the last custom disk
                    next if domain_disks.last.first == disk
                    expect(disk).to receive(:destroy)
                  end
                  expect(domain).to receive(:destroy).with(destroy_volumes: false, flags: 0)
                  expect(subject.call(env)).to be_nil
                end
              end
            end
          end
        end
      end

      context 'when has nvram' do
        let(:vagrantfile) do
          <<-EOF
          Vagrant.configure('2') do |config|
            config.vm.define :test
            config.vm.provider :libvirt do |libvirt|
              libvirt.nvram = "test"
            end
          end
          EOF
        end

        it 'sets destroy flags to keep nvram' do
          expect(domain).to receive(:destroy).with(destroy_volumes: true, flags: VagrantPlugins::ProviderLibvirt::Util::DomainFlags::VIR_DOMAIN_UNDEFINE_KEEP_NVRAM)
          expect(subject.call(env)).to be_nil
        end

        context 'when fog does not support destroy with flags' do
          before do
            expect(destroy_method).to receive(:parameters).and_return([[:opt, :options]])
          end

          it 'skips setting additional destroy flags' do
            expect(domain).to receive(:destroy).with(destroy_volumes: true)
            expect(subject.call(env)).to be_nil
          end
        end
      end

      context 'when has CDROMs attached' do
        let(:vagrantfile_providerconfig) do
          <<-EOF
              libvirt.storage :file, :device => :cdrom
          EOF
        end
        let(:domain_xml_file) { 'cdrom_domain.xml' }

        it 'uses explicit removal of disks' do
          expect(domain).to receive(:volumes).and_return([root_disk, nil])
          expect(libvirt_domain).to receive(:xml_desc).and_return(domain_xml)

          expect(domain).to_not receive(:destroy).with(destroy_volumes: true, flags: 0)
          expect(root_disk).to receive(:destroy)  # root disk remove
          expect(subject.call(env)).to be_nil
        end
      end
    end
  end
end
