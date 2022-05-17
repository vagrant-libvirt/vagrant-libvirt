# frozen_string_literal: true

require 'support/binding_proc'

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
          {:uri => "qemu:///system"},
        ],

        # explicit uri settings
        [ # transport and hostname
          {:uri => "qemu+ssh://localhost/system"},
          {:uri => "qemu+ssh://localhost/system", :connect_via_ssh => true, :host => "localhost", :username => nil},
        ],
        [ # tcp transport with port
          {:uri => "qemu+tcp://localhost:5000/system"},
          {:uri => "qemu+tcp://localhost:5000/system", :connect_via_ssh => false, :host => "localhost", :username => nil},
        ],
        [ # connect explicit to unix socket
          {:uri => "qemu+unix:///system"},
          {:uri => "qemu+unix:///system", :connect_via_ssh => false, :host => nil, :username => nil},
        ],
        [ # via libssh2 should enable ssh as well
          {:uri => "qemu+libssh2://user@remote/system?known_hosts=/home/user/.ssh/known_hosts"},
          {
            :uri => "qemu+libssh2://user@remote/system?known_hosts=/home/user/.ssh/known_hosts",
            :connect_via_ssh => true, :host => "remote", :username => "user",
          },
        ],
        [ # xen
          {:uri => "xen://remote/system?no_verify=1"},
          {
            :uri => "xen://remote/system?no_verify=1",
            :connect_via_ssh => false, :host => "remote", :username => nil,
            :id_ssh_key_file => nil,
          },
          {
            :setup => ProcWithBinding.new {
              expect(File).to_not receive(:file?)
            }
          }
        ],
        [ # xen
          {:uri => "xen+ssh://remote/system?no_verify=1"},
          {
            :uri => "xen+ssh://remote/system?no_verify=1",
            :connect_via_ssh => true, :host => "remote", :username => nil,
            :id_ssh_key_file => "/home/tests/.ssh/id_rsa",
          },
          {
            :setup => ProcWithBinding.new {
              expect(File).to receive(:file?).with("/home/tests/.ssh/id_rsa").and_return(true)
            }
          }
        ],

        # with LIBVIRT_DEFAULT_URI
        [ # all other set to default
          {},
          {:uri => "custom:///custom_path", :qemu_use_session => false},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "custom:///custom_path"},
          }
        ],
        [ # with session
          {},
          {:uri => "qemu:///session", :qemu_use_session => true},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "qemu:///session"},
          }
        ],
        [ # with session and using ssh infer connect by ssh and ignore host as not provided
          {},
          {:uri => "qemu+ssh:///session", :qemu_use_session => true, :connect_via_ssh => true, :host => nil},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "qemu+ssh:///session"},
          }
        ],
        [ # with session and using ssh to specific host with additional query options provided, infer host and ssh
          {},
          {:uri => "qemu+ssh://remote/session?keyfile=my_id_rsa", :qemu_use_session => true, :connect_via_ssh => true, :host => 'remote'},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "qemu+ssh://remote/session?keyfile=my_id_rsa"},
          }
        ],
        [ # when session not set
          {},
          {:uri => "qemu:///system", :qemu_use_session => false},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "qemu:///system"},
          }
        ],
        [ # when session appearing elsewhere
          {},
          {:uri => "qemu://remote/system?keyfile=my_session_id", :qemu_use_session => false},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => "qemu://remote/system?keyfile=my_session_id"},
          }
        ],

        # ignore LIBVIRT_DEFAULT_URI due to explicit settings
        [ # when uri explicitly set
          {:uri => 'qemu:///system'},
          {:uri => %r{qemu:///(system|session)}},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],
        [ # when host explicitly set
          {:host => 'remote'},
          {:uri => %r{qemu://remote/(system|session)}},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],
        [ # when connect_via_ssh explicitly set
          {:connect_via_ssh => true},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1}},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],
        [ # when username explicitly set without ssh
          {:username => 'my_user' },
          {:uri => %r{qemu:///(system|session)}, :username => 'my_user'},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],
        [ # when username explicitly set with host but without ssh
          {:username => 'my_user', :host => 'remote'},
          {:uri => %r{qemu://remote/(system|session)}, :username => 'my_user'},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],
        [ # when password explicitly set
          {:password => 'some_password'},
          {:uri => %r{qemu:///(system|session)}, :password => 'some_password'},
          {
            :env => {'LIBVIRT_DEFAULT_URI' => 'qemu:///custom'},
          }
        ],

        # driver settings
        [ # set to kvm only
          {:driver => 'kvm'},
          {:uri => %r{qemu:///(system|session)}},
        ],
        [ # set to qemu only
          {:driver => 'qemu'},
          {:uri => %r{qemu:///(system|session)}},
        ],
        [ # set to qemu with session enabled
          {:driver => 'qemu', :qemu_use_session => true},
          {:uri => "qemu:///session"},
        ],
        [ # set to openvz only
          {:driver => 'openvz'},
          {:uri => "openvz:///system"},
        ],
        [ # set to esx
          {:driver => 'esx'},
          {:uri => "esx:///"},
        ],
        [ # set to vbox only
          {:driver => 'vbox'},
          {:uri => "vbox:///session"},
        ],

        # connect_via_ssh settings
        [ # enabled
          {:connect_via_ssh => true},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1}},
        ],
        [ # enabled with user
          {:connect_via_ssh => true, :username => 'my_user'},
          {:uri => %r{qemu\+ssh://my_user@localhost/(system|session)\?no_verify=1}},
        ],
        [ # enabled with host
          {:connect_via_ssh => true, :host => 'remote_server'},
          {:uri => %r{qemu\+ssh://remote_server/(system|session)\?no_verify=1}},
        ],

        # id_ssh_key_file behaviour
        [ # set should take given value
          {:connect_via_ssh => true, :id_ssh_key_file => '/path/to/keyfile'},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1&keyfile=/path/to/keyfile}, :connect_via_ssh => true},
        ],
        [ # set should infer use of ssh
          {:id_ssh_key_file => '/path/to/keyfile'},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1&keyfile=/path/to/keyfile}, :connect_via_ssh => true},
        ],
        [ # connect_via_ssh should enable default but ignore due to not existing
          {:connect_via_ssh => true},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1}, :id_ssh_key_file => nil},
          {
            :setup => ProcWithBinding.new {
              expect(File).to receive(:file?).with("/home/tests/.ssh/id_rsa").and_return(false)
            }
          }
        ],
        [ # connect_via_ssh should enable default and include due to existing
          {:connect_via_ssh => true},
          {:uri => %r{qemu\+ssh://localhost/(system|session)\?no_verify=1&keyfile=/home/tests/\.ssh/id_rsa}, :id_ssh_key_file => '/home/tests/.ssh/id_rsa'},
          {
            :setup => ProcWithBinding.new {
              expect(File).to receive(:file?).with("/home/tests/.ssh/id_rsa").and_return(true)
            }
          }
        ],

        # socket behaviour
        [ # set
          {:socket => '/var/run/libvirt/libvirt-sock'},
          {:uri => %r{qemu:///(system|session)\?socket=/var/run/libvirt/libvirt-sock}},
        ],
      ].each do |inputs, outputs, options|
        opts = {}
        opts.merge!(options) if options

        it "should handle inputs #{inputs} with env (#{opts[:env]})" do
          # allow some of these to fail for now if marked as such
          if !opts[:allow_failure].nil?
            pending(opts[:allow_failure])
          end

          if !opts[:setup].nil?
            opts[:setup].apply_binding(binding)
          end

          inputs.each do |k, v|
            subject.instance_variable_set("@#{k}", v)
          end

          if !opts[:env].nil?
            opts[:env].each do |k, v|
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

          expect(got).to match(outputs.inject({}) { |h, (k, v)| h[k] = v.is_a?(Regexp) ? a_string_matching(v) : v; h })
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

    context '@system_uri' do
      [
        # system uri
        [ # transport and hostname
          {:uri => "qemu+ssh://localhost/session"},
          {:uri => "qemu+ssh://localhost/session", :system_uri => "qemu+ssh://localhost/system"},
        ],
        [ # explicitly set
          {:qemu_use_session => true, :system_uri => "custom://remote/system"},
          {:uri => "qemu:///session", :system_uri => "custom://remote/system"},
        ],
      ].each do |inputs, outputs, options|
        opts = {}
        opts.merge!(options) if options

        it "should handle inputs #{inputs} with env (#{opts[:env]})" do
          # allow some of these to fail for now if marked as such
          if !opts[:allow_failure].nil?
            pending(opts[:allow_failure])
          end

          if !opts[:setup].nil?
            opts[:setup].apply_binding(binding)
          end

          inputs.each do |k, v|
            subject.instance_variable_set("@#{k}", v)
          end

          if !opts[:env].nil?
            opts[:env].each do |k, v|
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
    end

    context '@proxy_command' do
      before(:example) do
        stub_const("ENV", fake_env)
        fake_env['HOME'] = "/home/tests"
      end

      [
        # no connect_via_ssh
        [
          {:host => "remote"},
          nil,
        ],

        # connect_via_ssh
        [ # host
          {:connect_via_ssh => true, :host => 'remote'},
          "ssh 'remote' -W %h:%p",
        ],
        [ # include user
          {:connect_via_ssh => true, :host => 'remote', :username => 'myuser'},
          "ssh 'remote' -l 'myuser' -W %h:%p",
        ],
        [ # remote contains port
          {:connect_via_ssh => true, :host => 'remote:2222'},
          "ssh 'remote' -p 2222 -W %h:%p",
        ],
        [ # include user and default ssh key exists
          {:connect_via_ssh => true, :host => 'remote', :username => 'myuser'},
          "ssh 'remote' -l 'myuser' -i '/home/tests/.ssh/id_rsa' -W %h:%p",
          {
            :setup => ProcWithBinding.new {
              expect(File).to receive(:file?).with("/home/tests/.ssh/id_rsa").and_return(true)
            }
          }
        ],

        # disable id_ssh_key_file
        [
          {:connect_via_ssh => true, :host => 'remote', :id_ssh_key_file => nil},
          "ssh 'remote' -W %h:%p",
        ],
        [ # include user
          {:connect_via_ssh => true, :host => 'remote', :id_ssh_key_file => nil},
          "ssh 'remote' -W %h:%p",
        ],

        # use @uri
        [
          {:uri => 'qemu+ssh://remote/system'},
          "ssh 'remote' -W %h:%p",
        ],
        [
          {:uri => 'qemu+ssh://myuser@remote/system'},
          "ssh 'remote' -l 'myuser' -W %h:%p",
        ],
        [
          {:uri => 'qemu+ssh://remote/system?keyfile=/some/path/to/keyfile'},
          "ssh 'remote' -i '/some/path/to/keyfile' -W %h:%p",
        ],

        # provide custom template
        [
          {:connect_via_ssh => true, :host => 'remote', :proxy_command => "ssh {host} nc %h %p" },
          "ssh remote nc %h %p",
        ],
        [
          {:connect_via_ssh => true, :host => 'remote', :username => 'myuser', :proxy_command => "ssh {host} nc %h %p" },
          "ssh remote nc %h %p",
        ],
        [
          {:connect_via_ssh => true, :host => 'remote', :username => 'myuser', :proxy_command => "ssh {host} -l {username} nc %h %p" },
          "ssh remote -l myuser nc %h %p",
        ],
      ].each do |inputs, proxy_command, options|
        opts = {}
        opts.merge!(options) if options

        it "should handle inputs #{inputs}" do
          # allow some of these to fail for now if marked as such
          if !opts[:allow_failure].nil?
            pending(opts[:allow_failure])
          end

          if !opts[:setup].nil?
            opts[:setup].apply_binding(binding)
          end

          inputs.each do |k, v|
            subject.instance_variable_set("@#{k}", v)
          end

          subject.finalize!

          expect(subject.proxy_command).to eq(proxy_command)
        end
      end
    end

    context '@usbctl_dev' do
      it 'should be empty by default' do
        subject.finalize!

        expect(subject.usbctl_dev).to eq({})
      end

      context 'when usb devices added' do
        it 'should inject a default controller' do
          subject.usb :vendor => '0x1234', :product => '0xabcd'

          subject.finalize!

          expect(subject.usbctl_dev).to eq({:model => 'qemu-xhci'})
        end

        context 'when user specified a controller' do
          it 'should retain the user setting' do
            subject.usb :vendor => '0x1234', :product => '0xabcd'
            subject.usb_controller :model => 'pii3-uchi'

            subject.finalize!
            expect(subject.usbctl_dev).to eq({:model => 'pii3-uchi'})
          end
        end
      end

      context 'when redirdevs entries added' do
        it 'should inject a default controller' do
          subject.redirdev :type => 'spicevmc'

          subject.finalize!

          expect(subject.usbctl_dev).to eq({:model => 'qemu-xhci'})
        end

        context 'when user specified a controller' do
          it 'should retain the user setting' do
            subject.redirdev :type => 'spicevmc'
            subject.usb_controller :model => 'pii3-uchi'

            subject.finalize!
            expect(subject.usbctl_dev).to eq({:model => 'pii3-uchi'})
          end
        end
      end
    end

    context '@channels' do
      it 'should be empty by default' do
        subject.finalize!

        expect(subject.channels).to be_empty
      end

      context 'when qemu_use_agent is set' do
        before do
          subject.qemu_use_agent = true
        end

        it 'should inject a qemu agent channel' do
          subject.finalize!

          expect(subject.channels).to_not be_empty
          expect(subject.channels).to match([a_hash_including({:target_name => 'org.qemu.guest_agent.0'})])
        end

        context 'when agent channel already added' do
          it 'should not modify the channels' do
            subject.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'

            subject.finalize!

            expect(subject.channels.length).to eq(1)
          end

          context 'when agent channel explicitly disbaled' do
            it 'should not include an agent channel' do
              subject.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :disabled => true

              subject.finalize!

              expect(subject.channels).to be_empty
            end
          end
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
      before do
        machine.config.instance_variable_get("@keys")[:vm] = vm
      end

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

    context 'with nvram defined' do
      before do
        subject.nvram = '/path/to/some/nvram'
      end

      it 'should be invalid as loader not set' do
        assert_invalid
      end

      context 'with loader defined' do
        it 'should be valid' do
          subject.loader = '/path/to/some/loader'

          assert_valid
        end
      end
    end

    context 'with cpu_mode and cpu_model defined' do
      it 'should discard model if mode is passthrough' do
        subject.cpu_mode = 'host-passthrough'
        subject.cpu_model = 'qemu64'
        assert_valid
        expect(subject.cpu_model).to be_empty
      end

      it 'should allow custom mode with model' do
        subject.cpu_mode = 'custom'
        subject.cpu_model = 'qemu64'
        assert_valid
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
          it 'should merge disks without assigning devices automatically' do
            one.storage(:file)
            two.storage(:file)
            subject.finalize!
            expect(subject.disks).to_not include(include(device: 'vdb'),
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
