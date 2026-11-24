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
            # Don't continue if image already exists in storage pool.
            volume = env[:machine].provider.driver.connection.volumes.all(
              name: disk[:name]
            ).first
            if volume and volume.id
              disk[:preexisting] = true
            elsif disk[:path]
              @@lock.synchronize do
                storage_send_box_image(env, config, disk[:path], disk)
                disk[:uploaded] = true
              end
            else
              # make the disk. equivalent to:
              # qemu-img create -f qcow2 <path> 5g
              begin
                env[:machine].provider.driver.connection.volumes.create(
                  :name        => disk[:name],
                  :pool_name   => disk[:pool],
                  :format_type => disk[:type],
                  :capacity    => disk[:size],
                  :owner       => storage_uid(env),
                  :group       => storage_gid(env),
                  # :allocation  => ?,
                )
              rescue Libvirt::Error => e
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
