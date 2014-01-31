module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Adds support for vagrant's `forward_ports` configuration directive.
      class ForwardPorts
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_libvirt::action::forward_ports')
        end

        def call(env)
          @env = env

          # Get the ports we're forwarding
          env[:forwarded_ports] = compile_forwarded_ports(env[:machine].config)

          # Warn if we're port forwarding to any privileged ports
          env[:forwarded_ports].each do |fp|
            if fp[:host] <= 1024
              env[:ui].warn I18n.t(
                'vagrant.actions.vm.forward_ports.privileged_ports'
              )
              break
            end
          end

          # Continue, we need the VM to be booted in order to grab its IP
          @app.call env

          if @env[:forwarded_ports].any?
            env[:ui].info I18n.t('vagrant.actions.vm.forward_ports.forwarding')
            forward_ports
          end
        end

        def forward_ports
          @env[:forwarded_ports].each do |fp|
            message_attributes = {
              adapter: 'eth0',
              guest_port: fp[:guest],
              host_port: fp[:host]
            }

            @env[:ui].info(I18n.t(
                'vagrant.actions.vm.forward_ports.forwarding_entry',
                message_attributes
            ))

            ssh_pid = redirect_port(
              @env[:machine].name,
              fp[:host_ip] || '0.0.0.0',
              fp[:host],
              fp[:guest_ip] || @env[:machine].provider.ssh_info[:host],
              fp[:guest]
            )
            store_ssh_pid(fp[:host], ssh_pid)
          end
        end

        private

        def compile_forwarded_ports(config)
          mappings = {}

          config.vm.networks.each do |type, options|
            next if options[:disabled]

            if type == :forwarded_port && options[:id] != 'ssh'
              if options.fetch(:host_ip, '').to_s.strip.empty?
                options.delete(:host_ip)
              end
              mappings[options[:host]] = options
            end
          end

          mappings.values
        end

        def redirect_port(machine, host_ip, host_port, guest_ip, guest_port)
          params = %W(
            #{machine}
            -L #{host_ip}:#{host_port}:#{guest_ip}:#{guest_port}
            -N
          ).join(' ')
          # TODO get options without shelling out
          options = `vagrant ssh-config #{machine} | awk '{printf " -o "$1"="$2}'`
          ssh_cmd = "ssh #{options} #{params}"

          @logger.debug "Forwarding port with `#{ssh_cmd}`"
          spawn(ssh_cmd,  [:out, :err] => '/dev/null')
        end

        def store_ssh_pid(host_port, ssh_pid)
          data_dir = @env[:machine].data_dir.join('pids')
          data_dir.mkdir unless data_dir.directory?

          data_dir.join("ssh_#{host_port}.pid").open('w') do |pid_file|
            pid_file.write(ssh_pid)
          end
        end
      end
    end
  end
end

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Cleans up ssh-forwarded ports on VM halt/destroy.
      class ClearForwardedPorts
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new(
            'vagrant_libvirt::action::clear_forward_ports'
          )
        end

        def call(env)
          @env = env

          if ssh_pids.any?
            env[:ui].info I18n.t(
              'vagrant.actions.vm.clear_forward_ports.deleting'
            )
            ssh_pids.each do |pid|
              next unless ssh_pid?(pid)
              @logger.debug "Killing pid #{pid}"
              system "kill #{pid}"
            end

            @logger.info 'Removing ssh pid files'
            remove_ssh_pids
          else
            @logger.info 'No ssh pids found'
          end

          @app.call env
        end

        protected

        def ssh_pids
          glob = @env[:machine].data_dir.join('pids').to_s + '/ssh_*.pid'
          @ssh_pids = Dir[glob].map do |file|
            File.read(file).strip.chomp
          end
        end

        def ssh_pid?(pid)
          @logger.debug 'Checking if #{pid} is an ssh process '\
                        'with `ps -o cmd= #{pid}`'
          `ps -o cmd= #{pid}`.strip.chomp =~ /ssh/
        end

        def remove_ssh_pids
          glob = @env[:machine].data_dir.join('pids').to_s + '/ssh_*.pid'
          Dir[glob].each do |file|
            File.delete file
          end
        end
      end
    end
  end
end
