# frozen_string_literal: true

require 'vagrant'

module VagrantPlugins
  module ProviderLibvirt
    module Errors
      class VagrantLibvirtError < Vagrant::Errors::VagrantError
        error_namespace('vagrant_libvirt.errors')
      end

      class CallChainError < VagrantLibvirtError
        error_key(:call_chain_error)
      end

      # package not supported
      class PackageNotSupported < VagrantLibvirtError
        error_key(:package_not_supported)
      end

      class DuplicateDiskDevice < VagrantLibvirtError
        error_key(:duplicate_disk_device)
      end

      class NoDiskDeviceAvailable < VagrantLibvirtError
        error_key(:no_disk_device_available)
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
        error_key(:image_upload_error)
      end

      class ImageDownloadError < VagrantLibvirtError
        error_key(:image_download_error)
      end

      # Box exceptions, capture all under one
      class BoxError < VagrantLibvirtError
      end

      class BoxFormatMissingAttribute < BoxError
        error_key(:box_format_missing_attribute)
      end

      class BoxFormatDuplicateVolume < BoxError
        error_key(:box_format_duplicate_volume)
      end

      class BadBoxImage < VagrantLibvirtError
        error_key(:bad_box_image)
      end

      class NoBoxVolume < VagrantLibvirtError
        error_key(:no_box_volume)
      end

      class NoBoxVirtualSizeSet < VagrantLibvirtError
        error_key(:no_box_virtual_size)
      end

      class NoDiskVirtualSizeSet < VagrantLibvirtError
        error_key(:no_disk_virtual_size)
      end

      class NoBoxFormatSet < VagrantLibvirtError
        error_key(:no_box_format)
      end

      class WrongBoxFormatSet < VagrantLibvirtError
        error_key(:wrong_box_format)
      end

      class WrongDiskFormatSet < VagrantLibvirtError
        error_key(:wrong_disk_format)
      end

      # Fog Libvirt exceptions
      class FogError < VagrantLibvirtError
        error_key(:fog_error)
      end

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

      # Network exceptions
      class ManagementNetworkError < VagrantLibvirtError
        error_key(:management_network_error)
      end

      class NetworkNameAndAddressMismatch < VagrantLibvirtError
        error_key(:network_name_and_address_mismatch)
      end

      class DHCPMismatch < VagrantLibvirtError
        error_key(:dhcp_mismatch)
      end

      class CreateNetworkError < VagrantLibvirtError
        error_key(:create_network_error)
      end

      class DestroyNetworkError < VagrantLibvirtError
        error_key(:destroy_network_error)
      end

      class NetworkNotAvailableError < VagrantLibvirtError
        error_key(:network_not_available_error)
      end

      class AutostartNetworkError < VagrantLibvirtError
        error_key(:autostart_network_error)
      end

      class ActivateNetworkError < VagrantLibvirtError
        error_key(:activate_network_error)
      end

      class TunnelPortNotDefined < VagrantLibvirtError
        error_key(:tunnel_port_not_defined)
      end

      class ManagementNetworkRequired < VagrantLibvirtError
        error_key(:management_network_required)
      end

      # Other exceptions
      class InterfaceSlotNotAvailable < VagrantLibvirtError
        error_key(:interface_slot_not_available)
      end

      class InterfaceSlotExhausted < VagrantLibvirtError
        error_key(:interface_slot_exhausted)
      end

      class RsyncError < VagrantLibvirtError
        error_key(:rsync_error)
      end

      class DomainNameExists < VagrantLibvirtError
        error_key(:domain_name_exists)
      end

      class NoDomainError < VagrantLibvirtError
        error_key(:no_domain_error)
      end

      class AttachDeviceError < VagrantLibvirtError
        error_key(:attach_device_error)
      end

      class DetachDeviceError < VagrantLibvirtError
        error_key(:detach_device_error)
      end

      class NoIpAddressError < VagrantLibvirtError
        error_key(:no_ip_address_error)
      end

      class DeleteSnapshotError < VagrantLibvirtError
        error_key(:delete_snapshot_error)
      end

      class SerialCannotCreatePathError < VagrantLibvirtError
        error_key(:serial_cannot_create_path_error)
      end
    end
  end
end
