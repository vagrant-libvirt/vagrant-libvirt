require 'ostruct'
require 'pathname'

class EnvironmentHelper
  attr_writer :domain_name

  attr_accessor :random_hostname, :name, :default_prefix

  def [](value)
    send(value.to_sym)
  end

  def cpus
    4
  end

  def memory
    1024
  end

  %w(cpus cpu_mode loader nvram boot_order machine_type disk_bus disk_device nested volume_cache kernel cmd_line initrd graphics_type graphics_autoport graphics_port graphics_ip graphics_passwd video_type video_vram keymap storage_pool_name disks cdroms driver).each do |name|
    define_method(name.to_sym) do
      nil
    end
  end

  def machine
    self
  end

  def provider_config
    self
  end

  def root_path
    Pathname.new('./spec/support/foo')
  end

  def domain_name
    # noop
  end

  def libvirt_compute
    OpenStruct.new(servers: [])
  end
end
