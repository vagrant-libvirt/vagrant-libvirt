require "ostruct"
require "pathname"

class EnvironmentHelper

  attr_writer :domain_name

  attr_accessor :random_hostname, :name, :default_prefix

  def [](value)
    self.send(value.to_sym)
  end

  def machine
    self
  end

  def provider_config
    self
  end

  def root_path
    Pathname.new("./spec/support/foo")
  end

  def domain_name
    #noop
  end

  def libvirt_compute
    OpenStruct.new(servers: [])
  end

end
