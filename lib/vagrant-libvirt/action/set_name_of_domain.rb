module VagrantPlugins
  module ProviderLibvirt
    module Action

      # Setup name for domain and domain volumes.
      class SetNameOfDomain
        def initialize(app, env)
          @logger     = Log4r::Logger.new("vagrant_libvirt::action::set_name_of_domain")
          @app = app
        end

        def call(env)
          require 'securerandom'
          config = env[:machine].provider_config
          if config.default_prefix.nil?
            env[:domain_name] = env[:root_path].basename.to_s.dup
          else
            env[:domain_name] = config.default_prefix.to_s
          end
          env[:domain_name].gsub!(/[^-a-z0-9_]/i, '')
          env[:domain_name] << '_'
          env[:domain_name] << env[:machine].name.to_s
          
          begin
          @logger.info("Looking for domain #{env[:domain_name]} through list #{env[:libvirt_compute].servers.all}")
          # Check if the domain name is not already taken
          
            domain = ProviderLibvirt::Util::Collection.find_matching(
            env[:libvirt_compute].servers.all, env[:domain_name])
          rescue Fog::Errors::Error => e
            @logger.info("#{e}")
            domain = nil
          end

          @logger.info("Looking for domain #{env[:domain_name]}")

          if domain != nil
            raise ProviderLibvirt::Errors::DomainNameExists,
              :domain_name => env[:domain_name]
          end

          @app.call(env)
        end
      end

    end
  end
end

