# frozen_string_literal: true

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Adds support for vagrant's `forward_ports` configuration directive.
      class ForwardPorts
        @@lock = Mutex.new

        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_libvirt::action::forward_ports')
          @ui     = env[:ui]
        end

        def call(env)
          # Get the ports we're forwarding
          env[:forwarded_ports] = compile_forwarded_ports(env[:machine])

          # Warn if we're port forwarding to any privileged ports
          env[:forwarded_ports].each do |fp|
            next unless fp[:host] <= 1024
            @ui.warn I18n.t(
              'vagrant.actions.vm.forward_ports.privileged_ports'
            )
            break
          end

          # Continue, we need the VM to be booted in order to grab its IP
          @app.call env

          if env[:forwarded_ports].any?
            @ui.info I18n.t('vagrant.actions.vm.forward_ports.forwarding')
            forward_ports(env)
          end
        end

        def forward_ports(env)
          env[:forwarded_ports].each do |fp|
            message_attributes = {
              adapter: fp[:adapter] || 'eth0',
              guest_port: fp[:guest],
              host_port: fp[:host]
            }

            @ui.info(I18n.t(
                             'vagrant.actions.vm.forward_ports.forwarding_entry',
                             **message_attributes
            ))

            ssh_pid = redirect_port(
              env[:machine],
              fp[:host_ip] || '*',
              fp[:host],
              fp[:guest_ip] || env[:machine].provider.ssh_info[:host],
              fp[:guest],
              fp[:gateway_ports] || false
            )
            store_ssh_pid(env[:machine], fp[:host], ssh_pid)
          end
        end

        private

        def compile_forwarded_ports(machine)
          mappings = {}

          machine.config.vm.networks.each do |type, options|
            next if options[:disabled]

            if options[:protocol] == 'udp'
              @ui.warn I18n.t('vagrant_libvirt.warnings.forwarding_udp')
              next
            end

            next if type != :forwarded_port || ( options[:id] == 'ssh' && !machine.provider_config.forward_ssh_port )
            if options.fetch(:host_ip, '').to_s.strip.empty?
              options.delete(:host_ip)
            end
            mappings[options[:host]] = options
          end

          mappings.values
        end

        def redirect_port(machine, host_ip, host_port, guest_ip, guest_port,
                          gateway_ports)
          ssh_info = machine.ssh_info
          params = %W(
            -n
            -L
            #{host_ip}:#{host_port}:#{guest_ip}:#{guest_port}
            -N
            #{ssh_info[:host]}
          )
          params <<= '-g' if gateway_ports

          options = (%W(
            User=#{ssh_info[:username]}
            Port=#{ssh_info[:port]}
            UserKnownHostsFile=/dev/null
            ExitOnForwardFailure=yes
            ControlMaster=no
            StrictHostKeyChecking=no
            PasswordAuthentication=no
            ForwardX11=#{ssh_info[:forward_x11] ? 'yes' : 'no'}
            IdentitiesOnly=#{ssh_info[:keys_only] ? 'yes' : 'no'}
          ) + ssh_info[:private_key_path].map do |pk|
                "IdentityFile=\"#{pk}\""
              end
          ).map { |s| ['-o', s] }.flatten

          options += ['-o', "ProxyCommand=\"#{ssh_info[:proxy_command]}\""] if machine.provider_config.proxy_command && !machine.provider_config.proxy_command.empty?

          ssh_cmd = ['ssh'] + options + params

          # TODO: instead of this, try and lock and get the stdin from spawn...
          if host_port <= 1024
            @@lock.synchronize do
              # TODO: add i18n
              @ui.info 'Requesting sudo for host port(s) <= 1024'
              r = system('sudo -v')
              if r
                ssh_cmd.unshift('sudo') # add sudo prefix
              end
            end
          end

          @logger.debug "Forwarding port with `#{ssh_cmd.join(' ')}`"
          log_file = ssh_forward_log_file(
            machine, host_ip, host_port, guest_ip, guest_port,
          )
          @logger.info "Logging to #{log_file}"
          spawn(*ssh_cmd, [:out, :err] => [log_file, 'w'], :pgroup => true)
        end

        def ssh_forward_log_file(machine, host_ip, host_port, guest_ip, guest_port)
          log_dir = machine.data_dir.join('logs')
          log_dir.mkdir unless log_dir.directory?
          File.join(
            log_dir,
            'ssh-forwarding-%s_%s-%s_%s.log' %
              [host_ip, host_port, guest_ip, guest_port]
          )
        end

        def store_ssh_pid(machine, host_port, ssh_pid)
          data_dir = machine.data_dir.join('pids')
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
          @ui = env[:ui]
        end

        def call(env)
          pids = ssh_pids(env[:machine])
          if pids.any?
            @ui.info I18n.t(
              'vagrant.actions.vm.clear_forward_ports.deleting'
            )
            pids.each do |tag|
              next unless ssh_pid?(tag[:pid])
              @logger.debug "Killing pid #{tag[:pid]}"
              kill_cmd = ''

              if tag[:port] <= 1024
                kill_cmd += 'sudo ' # add sudo prefix
              end

              kill_cmd += "kill #{tag[:pid]}"
              @@lock.synchronize do
                system(kill_cmd)
              end
            end

            @logger.info 'Removing ssh pid files'
            remove_ssh_pids(env[:machine])
          else
            @logger.info 'No ssh pids found'
          end

          @app.call env
        end

        protected

        def ssh_pids(machine)
          glob = machine.data_dir.join('pids').to_s + '/ssh_*.pid'
          ssh_pids = Dir[glob].map do |file|
            {
              pid: File.read(file).strip.chomp,
              port: File.basename(file)['ssh_'.length..-1 * ('.pid'.length + 1)].to_i
            }
          end
        end

        def ssh_pid?(pid)
          @logger.debug "Checking if #{pid} is an ssh process "\
                        "with `ps -o command= #{pid}`"
          `ps -o command= #{pid}`.strip.chomp =~ /ssh/
        end

        def remove_ssh_pids(machine)
          glob = machine.data_dir.join('pids').to_s + '/ssh_*.pid'
          Dir[glob].each do |file|
            File.delete file
          end
        end
      end
    end
  end
end
