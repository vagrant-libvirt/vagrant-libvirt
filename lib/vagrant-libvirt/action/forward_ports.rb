module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Adds support for vagrant's `forward_ports` configuration directive.
      class ForwardPorts
        @@lock = Mutex.new

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
              adapter: fp[:adapter] || 'eth0',
              guest_port: fp[:guest],
              host_port: fp[:host]
            }

            @env[:ui].info(I18n.t(
                'vagrant.actions.vm.forward_ports.forwarding_entry',
                message_attributes
            ))

            ssh_pid = redirect_port(
              @env[:machine],
              fp[:host_ip] || 'localhost',
              fp[:host],
              fp[:guest_ip] || @env[:machine].provider.ssh_info[:host],
              fp[:guest],
              fp[:gateway_ports] || false
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

        def redirect_port(machine, host_ip, host_port, guest_ip, guest_port,
                          gateway_ports)
          ssh_info = machine.ssh_info
          params = %W(
            -L
            #{host_ip}:#{host_port}:#{guest_ip}:#{guest_port}
            -N
            #{ssh_info[:host]}
          ).join(' ')
          params += ' -g' if gateway_ports

          options = (%W(
            User=#{ssh_info[:username]}
            Port=#{ssh_info[:port]}
            UserKnownHostsFile=/dev/null
            StrictHostKeyChecking=no
            PasswordAuthentication=no
            ForwardX11=#{ssh_info[:forward_x11] ? 'yes' : 'no'}
          ) + ssh_info[:private_key_path].map do |pk|
              "IdentityFile='\"#{pk}\"'"
            end).map { |s| s.prepend('-o ') }.join(' ')

          options += " -o ProxyCommand=\"#{ssh_info[:proxy_command]}\"" if machine.provider_config.connect_via_ssh

          # TODO: instead of this, try and lock and get the stdin from spawn...
          ssh_cmd = ''
          if host_port <= 1024
            @@lock.synchronize do
              # TODO: add i18n
              @env[:ui].info 'Requesting sudo for host port(s) <= 1024'
              r = system('sudo -v')
              if r
                ssh_cmd << 'sudo '  # add sudo prefix
              end
            end
          end

          ssh_cmd << "ssh #{options} #{params}"

          @logger.debug "Forwarding port with `#{ssh_cmd}`"
          log_file = ssh_forward_log_file(host_ip, host_port,
                                          guest_ip, guest_port)
          @logger.info "Logging to #{log_file}"
          spawn(ssh_cmd,  [:out, :err] => [log_file, 'w'])
        end

        def ssh_forward_log_file(host_ip, host_port, guest_ip, guest_port)
          log_dir = @env[:machine].data_dir.join('logs')
          log_dir.mkdir unless log_dir.directory?
          File.join(
            log_dir,
            'ssh-forwarding-%s_%s-%s_%s.log' %
              [ host_ip, host_port, guest_ip, guest_port ]
          )
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
        @@lock = Mutex.new

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
            ssh_pids.each do |tag|
              next unless ssh_pid?(tag[:pid])
              @logger.debug "Killing pid #{tag[:pid]}"
              kill_cmd = ''

              if tag[:port] <= 1024
                kill_cmd << 'sudo '  # add sudo prefix
              end

              kill_cmd << "kill #{tag[:pid]}"
              @@lock.synchronize do
                system(kill_cmd)
              end
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
            {
              :pid => File.read(file).strip.chomp,
              :port => File.basename(file)['ssh_'.length..-1*('.pid'.length+1)].to_i
            }
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
