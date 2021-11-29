# frozen_string_literal: true

require 'securerandom'
module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Setup name for domain and domain volumes.
      class SetNameOfDomain
        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::set_name_of_domain')
          @app    = app
        end

        def call(env)
          env[:domain_name] = build_domain_name(env)

          begin
            @logger.info("Looking for domain #{env[:domain_name]}")
            # Check if the domain name is not already taken

            domain = env[:machine].provider.driver.connection.servers.all(
              name: env[:domain_name]
            )
          rescue Libvirt::RetrieveError => e
            @logger.info(e.to_s)
            domain = nil
          end

          unless domain.nil?
            raise ProviderLibvirt::Errors::DomainNameExists,
                  domain_name: env[:domain_name]
          end

          @app.call(env)
        end

        # build domain name
        # random_hostname option avoids
        # `domain about to create is already taken`
        # parsable and sortable by epoch time
        # @example
        #   development-centos-6-chef-11_1404488971_3b7a569e2fd7c554b852
        # @return [String] Libvirt domain name
        def build_domain_name(env)
          config = env[:machine].provider_config
          domain_name =
            if config.default_prefix.nil?
              env[:root_path].basename.to_s.dup.concat('_')
            elsif config.default_prefix.empty?
              # don't have any prefix, not even "_"
              String.new
            else
              config.default_prefix.to_s.dup
            end
          domain_name << env[:machine].name.to_s
          domain_name.gsub!(/[^-a-z0-9_\.]/i, '')
          domain_name << "_#{Time.now.utc.to_i}_#{SecureRandom.hex(10)}" if config.random_hostname
          domain_name
        end
      end
    end
  end
end
