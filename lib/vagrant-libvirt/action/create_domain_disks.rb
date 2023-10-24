# frozen_string_literal: true

require 'log4r'

require 'vagrant-libvirt/util/storage_util'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class CreateDomainDisks
        include VagrantPlugins::ProviderLibvirt::Util::StorageUtil

        @@lock = Mutex.new

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::create_domain_disks')
          @app = app
        end

        def call(env)
          # Get config.
          config = env[:machine].provider_config

          disks = env[:disks] || []

          disks.each do |disk|
            # make the disk. equivalent to:
            # qemu-img create -f qcow2 <path> 5g
            begin
              env[:machine].provider.driver.connection.volumes.create(
                name: disk[:name],
                format_type: disk[:type],
                path: disk[:absolute_path],
                capacity: disk[:size],
                owner: storage_uid(env),
                group: storage_gid(env),
                #:allocation => ?,
                pool_name: disk[:pool],
              )
            rescue Libvirt::Error => e
              # It is hard to believe that e contains just a string
              # and no useful error code!
              msgs = [disk[:name], disk[:absolute_path]].map do |name|
                "Call to virStorageVolCreateXML failed: " +
                "storage volume '#{name}' exists already"
              end
              if msgs.include?(e.message) and disk[:allow_existing]
                disk[:preexisting] = true
              else
                raise Errors::FogCreateDomainVolumeError,
                      error_message: e.message
              end
            end
          end

          # Continue the middleware chain.
          @app.call(env)
        end
      end
    end
  end
end
