require 'log4r'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      class ReadMacAddresses
        def initialize(app, _env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_libvirt::action::read_mac_addresses')
        end

        def call(env)
          env[:machine_mac_addresses] = read_mac_addresses(env[:machine].provider.driver.connection, env[:machine])
        end

        def read_mac_addresses(libvirt, machine)
          return nil if machine.id.nil?

          domain = libvirt.client.lookup_domain_by_uuid(machine.id)

          if domain.nil?
            @logger.info('Machine could not be found, assuming it got destroyed')
            machine.id = nil
            return nil
          end

          xml = Nokogiri::XML(domain.xml_desc)
          mac = xml.xpath('/domain/devices/interface/mac/@address')

          return {} if mac.empty?

          Hash[mac.each_with_index.map do |x, i|
            @logger.debug("interface[#{i}] = #{x.value}")
            [i, x.value]
          end]
        end
      end
    end
  end
end
