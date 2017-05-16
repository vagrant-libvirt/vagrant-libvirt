require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/config'

describe VagrantPlugins::ProviderLibvirt::Config do
  include_context 'unit'

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
