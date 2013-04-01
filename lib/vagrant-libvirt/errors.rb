require 'vagrant'

module VagrantPlugins
  module Libvirt
    module Errors
      class VagrantLibvirtError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_libvirt.errors")
      end

      # Storage pools and volumes exceptions
      class NoStoragePool < VagrantLibvirtError
        error_key(:no_storage_pool)
      end

      class DomainVolumeExists < VagrantLibvirtError
        error_key(:domain_volume_exists)
      end

      class NoDomainVolume < VagrantLibvirtError
        error_key(:no_domain_volume)
      end

      class CreatingStoragePoolError < VagrantLibvirtError
        error_key(:creating_storage_pool_error)
      end

      class ImageUploadError < VagrantLibvirtError
        error_key(:image_upload_error_error)
      end


      # Box exceptions
      class NoBoxVolume < VagrantLibvirtError
        error_key(:no_box_volume)
      end

      class NoBoxVirtualSizeSet < VagrantLibvirtError
        error_key(:no_box_virtual_size_error)
      end

      class NoBoxFormatSet < VagrantLibvirtError
        error_key(:no_box_format_error)
      end

      class WrongBoxFormatSet < VagrantLibvirtError
        error_key(:wrong_box_format_error)
      end


      # Fog libvirt exceptions
      class FogLibvirtConnectionError < VagrantLibvirtError
        error_key(:fog_libvirt_connection_error)
      end

      class FogCreateVolumeError < VagrantLibvirtError
        error_key(:fog_create_volume_error)
      end

      class FogCreateDomainVolumeError < VagrantLibvirtError
        error_key(:fog_create_domain_volume_error)
      end

      class FogCreateServerError < VagrantLibvirtError
        error_key(:fog_create_server_error)
      end


      # Other exceptions
      class InterfaceSlotNotAvailable < VagrantLibvirtError
        error_key(:interface_slot_not_available)
      end

      class RsyncError < VagrantLibvirtError
        error_key(:rsync_error)
      end

      class DomainNameExists < VagrantLibvirtError
        error_key(:domain_name_exists_error)
      end

      class NoDomainError < VagrantLibvirtError
        error_key(:no_domain_error)
      end

      class AttachDeviceError < VagrantLibvirtError
        error_key(:attach_device_error)
      end

      class NoIpAddressError < VagrantLibvirtError
        error_key(:no_ip_address_error)
      end

      class IpAddressMismatchError < VagrantLibvirtError
        error_key(:ip_address_mismatch_error)
      end

    end
  end
end
