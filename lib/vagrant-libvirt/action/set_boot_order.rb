require 'log4r'
require 'nokogiri'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # boot order useful for pxe in discovery workflow
      class SetBootOrder
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new('vagrant_libvirt::action::set_boot_order')
          config = env[:machine].provider_config
          @boot_order = config.boot_order
        end

        def call(env)
          # Get domain first
          begin
            domain = env[:machine].provider
                                  .driver
                                  .connection
                                  .client
                                  .lookup_domain_by_uuid(
                                    env[:machine].id.to_s
                                  )
          rescue => e
            raise Errors::NoDomainError,
                  error_message: e.message
          end

          # Only execute specific boot ordering if this is defined
          # in the Vagrant file
          if @boot_order.count >= 1

            # If a domain is initially defined with no box or disk or
            # with an explicit boot order, libvirt adds <boot dev="foo">
            # This conflicts with an explicit boot_order configuration,
            # so we need to remove it from the domain xml and feed it back.
            # Also see https://bugzilla.redhat.com/show_bug.cgi?id=1248514
            # as to why we have to do this after all devices have been defined.
            xml = Nokogiri::XML(domain.xml_desc)
            xml.search('/domain/os/boot').each(&:remove)

            # Parse the XML and find each defined drive and network interfacee
            hd = xml.search("/domain/devices/disk[@device='disk']")
            cdrom = xml.search("/domain/devices/disk[@device='cdrom']")
            # implemented only for 1 network
            nets = @boot_order.flat_map do |x|
              x.class == Hash ? x : nil
            end.compact
            raise 'Defined only for 1 network for boot' if nets.size > 1
            network = search_network(nets, xml)

            # Generate an array per device group and a flattened
            # array from all of those
            devices = { 'hd' => hd,
                        'cdrom' => cdrom,
                        'network' => network }

            final_boot_order = final_boot_order(@boot_order, devices)
            # Loop over the entire defined boot order array and
            # create boot order entries in the domain XML
            final_boot_order.each_with_index do |node, index|
              boot = "<boot order='#{index + 1}'/>"
              node.add_child(boot)
              logger_msg(node, index)
            end

            # Finally redefine the domain XML through libvirt
            # to apply the boot ordering
            env[:machine].provider
                         .driver
                         .connection
                         .client
                         .define_domain_xml(xml.to_s)
          end

          @app.call(env)
        end

        def final_boot_order(boot_order, devices)
          boot_order.flat_map do |category|
            devices[category.class == Hash ? category.keys.first : category]
          end
        end

        def search_network(nets, xml)
          str = '/domain/devices/interface'
          str += "[(@type='network' or @type='udp' or @type='bridge')"
          unless nets.empty?
            str += " and source[@network='#{nets.first['network']}']"
          end
          str += ']'
          @logger.debug(str)
          xml.search(str)
        end

        def logger_msg(node, index)
          name = if node.name == 'disk'
                   node['device']
                 elsif node.name == 'interface'
                   node.name
                 end
          @logger.debug "Setting #{name} to boot index #{index + 1}"
        end
      end
    end
  end
end
