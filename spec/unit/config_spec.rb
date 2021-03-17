require 'spec_helper'
require 'support/sharedcontext'

require 'vagrant-libvirt/config'

describe VagrantPlugins::ProviderLibvirt::Config do
  include_context 'unit'

  let(:fake_env) { Hash.new }

  describe '#clock_timer' do
    it 'should handle all options' do
      expect(
        subject.clock_timer(
          :name => 'rtc',
          :track => 'wall',
          :tickpolicy => 'delay',
          :present => 'yes',
        ).length
      ).to be(1)
      expect(
        subject.clock_timer(
          :name => 'tsc',
          :tickpolicy => 'delay',
          :frequency => '100',
          :mode => 'auto',
          :present => 'yes',
        ).length
      ).to be(2)
    end

    it 'should correctly save the options' do
      opts = {:name => 'rtc', :track => 'wall'}
      expect(subject.clock_timer(opts).length).to be(1)

      expect(subject.clock_timers[0]).to eq(opts)

      opts[:name] = 'tsc'
      expect(subject.clock_timers[0]).to_not eq(opts)
    end

    it 'should error name option is missing' do
      expect{ subject.clock_timer(:track => "wall") }.to raise_error("Clock timer name must be specified")
    end

    it 'should error if nil value for option supplied' do
      expect{ subject.clock_timer(:name => "rtc", :track => nil) }.to raise_error("Value of timer option track is nil")
    end

    it 'should error if unrecognized option specified' do
      expect{ subject.clock_timer(:name => "tsc", :badopt => "value") }.to raise_error("Unknown clock timer option: badopt")
    end
  end

  describe '#finalize!' do
    it 'is valid with defaults' do
      subject.finalize!
    end

    context '@uri' do
      before(:example) do
        stub_const("ENV", fake_env)
        fake_env['HOME'] = "/home/tests"
      end

      # table describing expected behaviour of inputs that affect the resulting uri as
      # well as any subsequent settings that might be inferred if the uri was
      # explicitly set.
      [
        # settings
        [ # all default
          {},
          {:uri => "qemu:///system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa"},
        ],

        # with LIBVIRT_DEFAULT_URI
        [ # all other set to default
          {},
          {:uri => "custom:///custom_path", :qemu_use_session => false},
          {'LIBVIRT_DEFAULT_URI' => "custom:///custom_path"},
        ],
        [ # with session
          {},
          {:uri => "qemu:///session", :qemu_use_session => true},
          {'LIBVIRT_DEFAULT_URI' => "qemu:///session"},
        ],
        [ # with session and using ssh
          {},
          {:uri => "qemu+ssh:///session", :qemu_use_session => true},
          {'LIBVIRT_DEFAULT_URI' => "qemu+ssh:///session"},
        ],
        [ # with session and using ssh infer host and connect by ssh
          {},
          {:uri => "qemu+ssh:///session", :qemu_use_session => true, :connect_via_ssh => true, :host => 'localhost'},
          {'LIBVIRT_DEFAULT_URI' => "qemu+ssh:///session"},
          "not yet inferring connect_via_ssh", # once working remove the preceding test
        ],
        [ # with session and using ssh to specific host with additional query options provided
          {},
          {:uri => "qemu+ssh://remote/session?keyfile=my_id_rsa", :qemu_use_session => true},
          {'LIBVIRT_DEFAULT_URI' => "qemu+ssh://remote/session?keyfile=my_id_rsa"},
        ],
        [ # with session and using ssh to specific host with additional query options provided, infer host and ssh
          {},
          {:uri => "qemu+ssh://remote/session?keyfile=my_id_rsa", :qemu_use_session => true, :connect_via_ssh => true, :host => 'remote'},
          {'LIBVIRT_DEFAULT_URI' => "qemu+ssh://remote/session?keyfile=my_id_rsa"},
          "not yet inferring host correctly", # once working remove the preceding test
        ],
        [ # when session not set
          {},
          {:uri => "qemu:///system", :qemu_use_session => false},
          {'LIBVIRT_DEFAULT_URI' => "qemu:///system"},
        ],
        [ # when session appearing elsewhere
          {},
          {:uri => "qemu://remote/system?keyfile=my_session_id", :qemu_use_session => false},
          {'LIBVIRT_DEFAULT_URI' => "qemu://remote/system?keyfile=my_session_id"},
        ],

        # ignore LIBVIRT_DEFAULT_URI due to explicit settings
        [ # when uri explicitly set
          {:uri => 'qemu:///system'},
          {:uri => 'qemu:///system'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],
        [ # when host explicitly set
          {:host => 'remote'},
          {:uri => 'qemu://remote/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],
        [ # when connect_via_ssh explicitly set
          {:connect_via_ssh => true},
          {:uri => 'qemu+ssh://localhost/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],
        [ # when username explicitly set without host
          {:username => 'my_user' },
          {:uri => 'qemu:///system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],
        [ # when username explicitly set with host
          {:username => 'my_user', :host => 'remote'},
          {:uri => 'qemu://remote/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],
        [ # when password explicitly set
          {:password => 'some_password'},
          {:uri => 'qemu:///system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa'},
          {'LIBVIRT_DEFAULT_URI' => 'qemu://session'},
        ],

        # driver settings
        [ # set to kvm only
          {:driver => 'kvm', :id_ssh_key_file => nil},
          {:uri => "qemu:///system?no_verify=1"},
        ],
        [ # set to qemu only
          {:driver => 'qemu', :id_ssh_key_file => nil},
          {:uri => "qemu:///system?no_verify=1"},
        ],
        [ # set to qemu with session enabled
          {:driver => 'qemu', :qemu_use_session => true, :id_ssh_key_file => nil},
          {:uri => "qemu:///session?no_verify=1"},
        ],
        [ # set to openvz only
          {:driver => 'openvz', :id_ssh_key_file => nil},
          {:uri => "openvz:///system?no_verify=1"},
        ],
        [ # set to esx
          {:driver => 'esx'},
          {:uri => "esx:///"},
          {},
          "Should not be adding query options that don't work to esx connection uri",
        ],
        [ # set to vbox only
          {:driver => 'vbox', :id_ssh_key_file => nil},
          {:uri => "vbox:///session?no_verify=1"},
        ],

        # connect_via_ssh settings
        [ # enabled
          {:connect_via_ssh => true},
          {:uri => "qemu+ssh://localhost/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa"},
        ],
        [ # enabled with user
          {:connect_via_ssh => true, :username => 'my_user'},
          {:uri => "qemu+ssh://my_user@localhost/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa"},
        ],
        [ # enabled with host
          {:connect_via_ssh => true, :host => 'remote_server'},
          {:uri => "qemu+ssh://remote_server/system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa"},
        ],

        # id_ssh_key_file behaviour
        [ # set
          {:id_ssh_key_file => '/path/to/keyfile'},
          {:uri => "qemu:///system?no_verify=1&keyfile=/path/to/keyfile"},
        ],
        [ # set infer use of ssh
          {:id_ssh_key_file => '/path/to/keyfile'},
          {:uri => "qemu+ssh:///system?no_verify=1&keyfile=/path/to/keyfile"},
          {},
          "setting of ssh key file does not yet enable connect via ssh",
        ],

        # socket behaviour
        [ # set
          {:socket => '/var/run/libvirt/libvirt-sock'},
          {:uri => "qemu:///system?no_verify=1&keyfile=/home/tests/.ssh/id_rsa&socket=/var/run/libvirt/libvirt-sock"},
        ],
      ].each do |inputs, outputs, env, allow_failure|
        it "should handle inputs #{inputs} with env #{env}" do
          # allow some of these to fail for now if marked as such
          if !allow_failure.nil?
            pending(allow_failure)
          end

          inputs.each do |k, v|
            subject.instance_variable_set("@#{k}", v)
          end

          if !env.nil?
            env.each do |k, v|
              fake_env[k] = v
            end
          end

          subject.finalize!

          # ensure failed output indicates which settings are incorrect in the failed test
          got = subject.instance_variables.each_with_object({}) do |name, hash|
            if outputs.key?(name.to_s[1..-1].to_sym)
              hash["#{name.to_s[1..-1]}".to_sym] =subject.instance_variable_get(name)
            end
          end
          expect(got).to eq(outputs)
        end
      end

      context 'when invalid @driver is defined' do
        it "should raise exception for unrecognized" do
          subject.driver = "bad-driver"

          expect { subject.finalize! }.to raise_error("Require specify driver bad-driver")
        end
      end

      context 'when invalid @uri is defined' do
        it "should raise exception for unrecognized" do
          subject.uri = "://bad-uri"

          expect { subject.finalize! }.to raise_error("@uri set to invalid uri '://bad-uri'")
        end
      end
    end
  end

  def assert_invalid
    subject.finalize!
    errors = subject.validate(machine)
    raise "No errors: #{errors.inspect}" if errors.values.all?(&:empty?)
  end

  def assert_valid
    subject.finalize!
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

    context 'clock_timers' do
      it 'should merge clock_timers' do
        one.clock_timer(:name => 'rtc', :tickpolicy => 'catchup')
        two.clock_timer(:name => 'hpet', :present => 'no')

        expect(subject.clock_timers).to include(include(name: 'rtc'),
                                                include(name: 'hpet'))
      end
    end
  end
end
