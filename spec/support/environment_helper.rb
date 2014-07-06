require "ostruct"
require "pathname"

class EnvironmentHelper

  attr_writer :default_prefix, :domain_name

  def [](value)
    self.send(value.to_sym)
  end

  def machine
    self
  end

  def provider_config
    self
  end

  def default_prefix
    # noop 
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
