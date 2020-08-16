require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/config'

describe VagrantPlugins::ProviderLibvirt::Config do
  include_context 'unit'

  let(:fake_env) { Hash.new }

  describe '#finalize!' do
    it 'is valid with defaults' do
      subject.finalize!
    end

    context '@uri' do
      before(:example) do
        stub_const("ENV", fake_env)
      end

      context 'when @driver is defined' do
        defaults = {'id_ssh_key_file' => nil}
        [
          [
            {'driver' => 'kvm'},
            'qemu:///system?no_verify=1',
            false,
          ],
          [
            {'driver' => 'qemu'},
            'qemu:///system?no_verify=1',
            false,
          ],
          [
            {'driver' => 'qemu', 'qemu_use_session' => true},
            'qemu:///session?no_verify=1',
            true,
          ],
          [
            {'driver' => 'openvz'},
            'openvz:///system?no_verify=1',
            false,
          ],
          [
            {'driver' => 'vbox'},
            'vbox:///session?no_verify=1',
            false,
          ],
        ].each do |inputs, output_uri, output_session|
          it "should detect #{inputs}" do
            inputs.merge(defaults).each do |k, v|
              subject.instance_variable_set("@#{k}", v)
            end

            subject.finalize!
            expect(subject.uri).to eq(output_uri)
            expect(subject.qemu_use_session).to eq(output_session)
          end
        end

        it "should raise exception for unrecognized" do
          subject.driver = "bad-driver"

          expect { subject.finalize! }.to raise_error("Require specify driver bad-driver")
        end
      end

      context 'when @connect_via_ssh defined' do
        defaults = {'driver' => 'qemu', 'id_ssh_key_file' => nil}
        [
          [
            {'connect_via_ssh' => true},
            'qemu+ssh://localhost/system?no_verify=1',
          ],
          [
            {'connect_via_ssh' => true, 'username' => 'my_user'},
            'qemu+ssh://my_user@localhost/system?no_verify=1',
          ],
          [
            {'connect_via_ssh' => true, 'host' => 'remote_server'},
            'qemu+ssh://remote_server/system?no_verify=1',
          ],
        ].each do |inputs, output_uri|
          it "should detect #{inputs}" do
            inputs.merge(defaults).each do |k, v|
              subject.instance_variable_set("@#{k}", v)
            end

            subject.finalize!
            expect(subject.uri).to eq(output_uri)
          end
        end
      end

      context 'when @id_ssh_key_file defined' do
        defaults = {'driver' => 'qemu'}
        [
          [
            {},
            'qemu:///system?no_verify=1&keyfile=/home/user/.ssh/id_rsa',
          ],
          [
            {'id_ssh_key_file' => '/path/to/keyfile'},
            'qemu:///system?no_verify=1&keyfile=/path/to/keyfile',
          ],
        ].each do |inputs, output_uri|
          it "should detect #{inputs}" do
            inputs.merge(defaults).each do |k, v|
              subject.instance_variable_set("@#{k}", v)
            end

            fake_env['HOME'] = '/home/user'

            subject.finalize!
            expect(subject.uri).to eq(output_uri)
          end
        end
      end

      context 'when @socket defined' do
        it "should detect @socket set" do
          subject.socket = '/var/run/libvirt/libvirt-sock'
          subject.id_ssh_key_file = false

          subject.finalize!
          expect(subject.uri).to eq('qemu:///system?no_verify=1&socket=/var/run/libvirt/libvirt-sock')
        end
      end
    end
  end

  def assert_invalid
    errors = subject.validate(machine)
    raise "No errors: #{errors.inspect}" if errors.values.all?(&:empty?)
  end

  def assert_valid
    errors = subject.validate(machine)
    raise "Errors: #{errors.inspect}" unless errors.values.all?(&:empty?)
  end

  describe '#validate' do
    it 'is valid with defaults' do
      assert_valid
    end

    context 'with disks defined' do
      before { expect(machine).to receive(:provider_config).and_return(subject).at_least(:once) }

      it 'is valid if relative path used for disk' do
        subject.storage :file, path: '../path/to/file.qcow2'
        assert_valid
      end

      it 'should be invalid if absolute path used for disk' do
        subject.storage :file, path: '/absolute/path/to/file.qcow2'
        assert_invalid
      end
    end

    context 'with mac defined' do
      let (:vm) { double('vm') }
      before { expect(machine.config).to receive(:vm).and_return(vm) }

      it 'is valid with valid mac' do
        expect(vm).to receive(:networks).and_return([[:public, { mac: 'aa:bb:cc:dd:ee:ff' }]])
        assert_valid
      end

      it 'is valid with MAC containing no delimiters' do
        network = [:public, { mac: 'aabbccddeeff' }]
        expect(vm).to receive(:networks).and_return([network])
        assert_valid
        expect(network[1][:mac]).to eql('aa:bb:cc:dd:ee:ff')
      end

      it 'should be invalid if MAC not formatted correctly' do
        expect(vm).to receive(:networks).and_return([[:public, { mac: 'aa/bb/cc/dd/ee/ff' }]])
        assert_invalid
      end
    end
  end

  describe '#merge' do
    let(:one) { described_class.new }
    let(:two) { described_class.new }

    subject { one.merge(two) }

    context 'storage' do
      context 'with disks' do
        context 'assigned specific devices' do
          it 'should merge disks with specific devices' do
            one.storage(:file, device: 'vdb')
            two.storage(:file, device: 'vdc')
            subject.finalize!
            expect(subject.disks).to include(include(device: 'vdb'),
                                             include(device: 'vdc'))
          end
        end

        context 'without devices given' do
          it 'should merge disks with different devices assigned automatically' do
            one.storage(:file)
            two.storage(:file)
            subject.finalize!
            expect(subject.disks).to include(include(device: 'vdb'),
                                             include(device: 'vdc'))
          end
        end
      end

      context 'with cdroms only' do
        context 'assigned specific devs' do
          it 'should merge disks with specific devices' do
            one.storage(:file, device: :cdrom, dev: 'hda')
            two.storage(:file, device: :cdrom, dev: 'hdb')
            subject.finalize!
            expect(subject.cdroms).to include(include(dev: 'hda'),
                                              include(dev: 'hdb'))
          end
        end

        context 'without devs given' do
          it 'should merge cdroms with different devs assigned automatically' do
            one.storage(:file, device: :cdrom)
            two.storage(:file, device: :cdrom)
            subject.finalize!
            expect(subject.cdroms).to include(include(dev: 'hda'),
                                              include(dev: 'hdb'))
          end
        end
      end
    end
  end
end
