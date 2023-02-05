# frozen_string_literal: true

require 'log4r'

require 'rexml/document'
require 'rexml/formatters/pretty'
require 'rexml/xpath'

require 'vagrant-libvirt/util/xml'

module VagrantPlugins
  module ProviderLibvirt
    module Action
      # Just start the domain.
      class StartDomain

        def initialize(app, _env)
          @logger = Log4r::Logger.new('vagrant_libvirt::action::start_domain')
          @app = app
        end

        def call(env)
          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain.nil?

          config = env[:machine].provider_config

          # update domain settings on change.
          libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(env[:machine].id)

          # Libvirt API doesn't support modifying memory on NUMA enabled CPUs
          # http://libvirt.org/git/?p=libvirt.git;a=commit;h=d174394105cf00ed266bf729ddf461c21637c736
          if config.numa_nodes == nil
            if config.memory.to_i * 1024 != libvirt_domain.max_memory
              libvirt_domain.max_memory = config.memory.to_i * 1024
              libvirt_domain.memory = libvirt_domain.max_memory
            end
          end

          # XML definition manipulation
          descr = libvirt_domain.xml_desc(1)
          xml_descr = REXML::Document.new descr
          descr_changed = false

          # For outputting XML for comparison
          formatter = REXML::Formatters::Pretty.new

          # additional disk bus
          config.disks.each do |disk|
            device = disk[:device]
            bus = disk[:bus]
            REXML::XPath.each(xml_descr, '/domain/devices/disk[@device="disk"]/target[@dev="' + device + '"]') do |disk_target|
              next unless disk_target.attributes['bus'] != bus
              @logger.debug "disk #{device} bus updated from '#{disk_target.attributes['bus']}' to '#{bus}'"
              descr_changed = true
              disk_target.attributes['bus'] = bus
              disk_target.parent.delete_element("#{disk_target.parent.xpath}/address")
            end
          end

          # disk_bus
          REXML::XPath.each(xml_descr, '/domain/devices/disk[@device="disk"]/target[@dev="vda"]') do |disk_target|
            next unless disk_target.attributes['bus'] != config.disk_bus
            @logger.debug "domain disk bus updated from '#{disk_target.attributes['bus']}' to '#{config.disk_bus}'"
            descr_changed = true
            disk_target.attributes['bus'] = config.disk_bus
            disk_target.parent.delete_element("#{disk_target.parent.xpath}/address")
          end

          # Interface type
          unless config.nic_model_type.nil?
            REXML::XPath.each(xml_descr, '/domain/devices/interface/model') do |iface_model|
              if iface_model.attributes['type'] != config.nic_model_type
                @logger.debug "network type updated from '#{iface_model.attributes['type']}' to '#{config.nic_model_type}'"
                descr_changed = true
                iface_model.attributes['type'] = config.nic_model_type
              end
            end
          end

          # vCpu count
          vcpus_count = libvirt_domain.num_vcpus(0)
          if config.cpus.to_i != vcpus_count
            @logger.debug "cpu count updated from '#{vcpus_count}' to '#{config.cpus}'"
            descr_changed = true
            REXML::XPath.first(xml_descr, '/domain/vcpu').text = config.cpus
          end

          # cpu_mode
          if !config.cpu_mode.nil?
            cpu = REXML::XPath.first(xml_descr, '/domain/cpu')
            if cpu.nil?
              @logger.debug "cpu_mode updated from not set to '#{config.cpu_mode}'"
              descr_changed = true
              cpu = REXML::Element.new('cpu', REXML::XPath.first(xml_descr, '/domain'))
              cpu.attributes['mode'] = config.cpu_mode
            else
              if cpu.attributes['mode'] != config.cpu_mode
                @logger.debug "cpu_mode updated from '#{cpu.attributes['mode']}' to '#{config.cpu_mode}'"
                descr_changed = true
                cpu.attributes['mode'] = config.cpu_mode
              end
            end

            if config.cpu_mode != 'host-passthrough'
              cpu_model = REXML::XPath.first(xml_descr, '/domain/cpu/model')
              if cpu_model.nil?
                if config.cpu_model.strip != ''
                  @logger.debug "cpu_model updated from not set to '#{config.cpu_model}'"
                  descr_changed = true
                  cpu_model = REXML::Element.new('model', REXML::XPath.first(xml_descr, '/domain/cpu'))
                  cpu_model.attributes['fallback'] = config.cpu_fallback
                  cpu_model.text = config.cpu_model
                end
              else
                if (cpu_model.text or '').strip != config.cpu_model.strip
                  @logger.debug "cpu_model text updated from #{cpu_model.text} to '#{config.cpu_model}'"
                  descr_changed = true
                  cpu_model.text = config.cpu_model
                end
                if cpu_model.attributes['fallback'] != config.cpu_fallback
                  @logger.debug "cpu_model fallback attribute updated from #{cpu_model.attributes['fallback']} to '#{config.cpu_fallback}'"
                  descr_changed = true
                  cpu_model.attributes['fallback'] = config.cpu_fallback
                end
              end
              vmx_feature = REXML::XPath.first(xml_descr, '/domain/cpu/feature[@name="vmx"]')
              svm_feature = REXML::XPath.first(xml_descr, '/domain/cpu/feature[@name="svm"]')
              if config.nested
                if vmx_feature.nil?
                  @logger.debug "nested mode enabled from unset by setting cpu vmx feature"
                  descr_changed = true
                  vmx_feature = REXML::Element.new('feature', REXML::XPath.first(xml_descr, '/domain/cpu'))
                  vmx_feature.attributes['policy'] = 'optional'
                  vmx_feature.attributes['name'] = 'vmx'
                end
                if svm_feature.nil?
                  @logger.debug "nested mode enabled from unset by setting cpu svm feature"
                  descr_changed = true
                  svm_feature = REXML::Element.new('feature', REXML::XPath.first(xml_descr, '/domain/cpu'))
                  svm_feature.attributes['policy'] = 'optional'
                  svm_feature.attributes['name'] = 'svm'
                end
              else
                unless vmx_feature.nil?
                  @logger.debug "nested mode disabled for cpu by removing vmx feature"
                  descr_changed = true
                  cpu.delete_element(vmx_feature)
                end
                unless svm_feature.nil?
                  @logger.debug "nested mode disabled for cpu by removing svm feature"
                  descr_changed = true
                  cpu.delete_element(svm_feature)
                end
              end
            elsif config.numa_nodes == nil
              unless cpu.elements.to_a.empty?
                @logger.debug "switching cpu_mode to host-passthrough and removing emulated cpu features"
                descr_changed = true
                cpu.elements.each do |elem|
                  cpu.delete_element(elem)
                end
              end
            end
          else
            xml_descr.delete_element('/domain/cpu')
          end

          # Clock - can change in complicated ways, so just build a new clock and compare
          newclock = REXML::Element.new('newclock')
          if not config.clock_absolute.nil?
            newclock.add_attribute('offset', 'absolute')
            newclock.add_attribute('start', config.clock_absolute)
          elsif not config.clock_adjustment.nil?
            newclock.add_attribute('offset', 'variable')
            newclock.add_attribute('basis', config.clock_basis)
            newclock.add_attribute('adjustment', config.clock_adjustment)
          elsif not config.clock_timezone.nil?
            newclock.add_attribute('offset', 'timezone')
            newclock.add_attribute('timezone', config.clock_timezone)
          else
            newclock.add_attribute('offset', config.clock_offset)
          end
          clock = REXML::XPath.first(xml_descr, '/domain/clock')
          if clock.attributes != newclock.attributes
            @logger.debug "clock definition changed"
            descr_changed = true
            clock.attributes.clear
            newclock.attributes.each do |attr, value|
              clock.add_attribute(attr, value)
            end
          end

          # clock timers - because timers can be added/removed, just rebuild and then compare
          if !config.clock_timers.empty? || clock.has_elements?
            oldclock = String.new
            formatter.write(REXML::XPath.first(xml_descr, '/domain/clock'), oldclock)
            clock.delete_element('//timer')
            config.clock_timers.each do |clock_timer|
              timer = REXML::Element.new('timer', clock)
              clock_timer.each do |attr, value|
                timer.attributes[attr.to_s] = value
              end
            end

            newclock = String.new
            formatter.write(clock, newclock)
            unless newclock.eql? oldclock
              @logger.debug "clock timers config changed"
              descr_changed = true
            end
          end

          # Launch security
          launchSecurity = REXML::XPath.first(xml_descr, '/domain/launchSecurity')
          unless config.launchsecurity_data.nil?
            if launchSecurity.nil?
              @logger.debug "Launch security has been added"
              launchSecurity = REXML::Element.new('launchSecurity', REXML::XPath.first(xml_descr, '/domain'))
              descr_changed = true
            end

            if launchSecurity.attributes['type'] != config.launchsecurity_data[:type]
              launchSecurity.attributes['type'] = config.launchsecurity_data[:type]
              descr_changed = true
            end

            [:cbitpos, :policy, :reducedPhysBits].each do |setting|
              setting_value = config.launchsecurity_data[setting]
              element = REXML::XPath.first(launchSecurity, setting.to_s)
              if !setting_value.nil?
                if element.nil?
                  element = launchSecurity.add_element(setting.to_s)
                  descr_changed = true
                end

                if element.text != setting_value
                  @logger.debug "launchSecurity #{setting.to_s} config changed"
                  element.text = setting_value
                  descr_changed = true
                end
              else
                if !element.nil?
                  launchSecurity.delete_element(setting.to_s)
                  descr_changed = true
                end
              end
            end

            controllers = REXML::XPath.each( xml_descr, '/domain/devices/controller')
            memballoon = REXML::XPath.each( xml_descr, '/domain/devices/memballoon')
            [controllers, memballoon].lazy.flat_map(&:lazy).each do |controller|
              driver_node = REXML::XPath.first(controller, 'driver')
              driver_node = controller.add_element('driver') if driver_node.nil?
              descr_changed = true if driver_node.attributes['iommu'] != 'on'
              driver_node.attributes['iommu'] = 'on'
            end
          else
            unless launchSecurity.nil?
              @logger.debug "Launch security to be deleted"

              descr_changed = true

              launchSecurity.parent.delete_element(launchSecurity)
            end

            REXML::XPath.each( xml_descr, '/domain/devices/controller') do | controller |
              driver_node = REXML::XPath.first(controller, 'driver')
              if !driver_node.nil?
                descr_changed = true if driver_node.attributes['iommu']
                driver_node.attributes.delete('iommu')
              end
            end
          end

          # Graphics
          graphics = REXML::XPath.first(xml_descr, '/domain/devices/graphics')
          if config.graphics_type != 'none'
            if graphics.nil?
              descr_changed = true
              graphics = REXML::Element.new('graphics', REXML::XPath.first(xml_descr, '/domain/devices'))
            end
            if graphics.attributes['type'] != config.graphics_type
              descr_changed = true
              graphics.attributes['type'] = config.graphics_type
            end
            if graphics.attributes['listen'] != config.graphics_ip
              descr_changed = true
              graphics.attributes['listen'] = config.graphics_ip
              graphics.delete_element('//listen')
            end
            unless config.graphics_port.nil? or config.graphics_port == -1
              if graphics.attributes['autoport'] != 'no'
                descr_changed = true
                graphics.attributes['autoport'] = 'no'
              end
              if graphics.attributes['port'] != config.graphics_port
                descr_changed = true
                graphics.attributes['port'] = config.graphics_port
              end
            else
              if graphics.attributes['autoport'] != config.graphics_autoport
                descr_changed = true
                graphics.attributes['autoport'] = config.graphics_autoport
                if config.graphics_autoport == 'no'
                  graphics.attributes['port'] = config.graphics_port
                else
                  graphics.attributes['port'] = '-1'
                end
              end
            end
            if graphics.attributes['websocket'] != config.graphics_websocket.to_s
              descr_changed = true
              graphics.attributes['websocket'] = config.graphics_websocket
            end
            if graphics.attributes['keymap'] != config.keymap
              descr_changed = true
              graphics.attributes['keymap'] = config.keymap
            end
            if graphics.attributes['passwd'] != config.graphics_passwd
              descr_changed = true
              if config.graphics_passwd.nil?
                graphics.attributes.delete 'passwd'
              else
                graphics.attributes['passwd'] = config.graphics_passwd
              end
            end
            graphics_gl = REXML::XPath.first(xml_descr, '/domain/devices/graphics/gl')
            if graphics_gl.nil?
              if config.graphics_gl
                graphics_gl = REXML::Element.new('gl', REXML::XPath.first(xml_descr, '/domain/devices/graphics'))
                graphics_gl.attributes['enable'] = 'yes'
                descr_changed = true
              end
            else
              if config.graphics_gl
                if graphics_gl.attributes['enable'] != 'yes'
                  graphics_gl.attributes['enable'] = 'yes'
                  descr_changed = true
                end
              else
                graphics_gl.parent.delete_element(graphics_gl)
                descr_changed = true
              end
            end
          else
            # graphics_type = none, remove entire element
            graphics.parent.delete_element(graphics) unless graphics.nil?
          end

          # TPM
          if [config.tpm_path, config.tpm_version].any?
            if config.tpm_path
              raise Errors::UpdateServerError, 'The TPM Path must be fully qualified' unless config.tpm_path[0].chr == '/'
            end

            # just build the tpm element every time
            # check at the end if it is different
            oldtpm = REXML::XPath.first(xml_descr, '/domain/devices/tpm')
            REXML::XPath.first(xml_descr, '/domain/devices').delete_element("tpm")
            newtpm = REXML::Element.new('tpm', REXML::XPath.first(xml_descr, '/domain/devices'))

            newtpm.attributes['model'] = config.tpm_model
            backend = newtpm.add_element('backend')
            backend.attributes['type'] = config.tpm_type

            case config.tpm_type
            when 'emulator'
              backend.attributes['version'] = config.tpm_version
            when 'passthrough'
              backend.add_element('device').attributes['path'] = config.tpm_path
            end

            unless "'#{newtpm}'".eql? "'#{oldtpm}'"
              @logger.debug "tpm config changed"
              descr_changed = true
            end
          end

          # Video device
          video = REXML::XPath.first(xml_descr, '/domain/devices/video')
          if !video.nil? && (config.graphics_type == 'none')
            # graphics_type = none, video devices are removed since there is no possible output
            @logger.debug "deleting video elements as config.graphics_type is none"
            descr_changed = true
            video.parent.delete_element(video)
          else
            video_model = REXML::XPath.first(xml_descr, '/domain/devices/video/model')
            if video_model.nil?
              @logger.debug "video updated from not set to type '#{config.video_type}' and vram '#{config.video_vram}'"
              descr_changed = true
              video_model = REXML::Element.new('model', REXML::XPath.first(xml_descr, '/domain/devices/video'))
              video_model.attributes['type'] = config.video_type
              video_model.attributes['vram'] = config.video_vram
            else
              if video_model.attributes['type'] != config.video_type || video_model.attributes['vram'] != config.video_vram.to_s
                @logger.debug "video type updated from '#{video_model.attributes['type']}' to '#{config.video_type}'"
                @logger.debug "video vram updated from '#{video_model.attributes['vram']}' to '#{config.video_vram}'"
                descr_changed = true
                video_model.attributes['type'] = config.video_type
                video_model.attributes['vram'] = config.video_vram
              end
            end
            video_accel = REXML::XPath.first(xml_descr, '/domain/devices/video/model/acceleration')
            if video_accel.nil?
              if config.video_accel3d
                video_accel = REXML::Element.new('acceleration', REXML::XPath.first(xml_descr, '/domain/devices/video/model'))
                video_accel.attributes['accel3d'] = 'yes'
                descr_changed = true
              end
            else
              if config.video_accel3d
                if video_accel.attributes['accel3d'] != 'yes'
                  video_accel.attributes['accel3d'] = 'yes'
                  descr_changed = true
                end
              else
                video_accel.parent.delete_element(video_accel)
                descr_changed = true
              end
            end
          end

          # Sound device
          if config.sound_type
            sound = REXML::XPath.first(xml_descr,'/domain/devices/sound/model')
          end


          # dtb
          if config.dtb
            dtb = REXML::XPath.first(xml_descr, '/domain/os/dtb')
            if dtb.nil?
              @logger.debug "dtb updated from not set to '#{config.dtb}'"
              descr_changed = true
              dtb = REXML::Element.new('dtb', REXML::XPath.first(xml_descr, '/domain/os'))
              dtb.text = config.dtb
            else
              if (dtb.text or '') != config.dtb
                @logger.debug "dtb updated from '#{dtb.text}' to '#{config.dtb}'"
                descr_changed = true
                dtb.text = config.dtb
              end
            end
          end

          # kernel and initrd
          if config.kernel
            kernel = REXML::XPath.first(xml_descr, '/domain/os/kernel')
            if kernel.nil?
              @logger.debug "kernel updated from not set to '#{config.kernel}'"
              descr_changed = true
              kernel = REXML::Element.new('kernel', REXML::XPath.first(xml_descr, '/domain/os'))
              kernel.text = config.kernel
            else
              if (kernel.text or '').strip != config.kernel
                @logger.debug "kernel updated from '#{kernel.text}' to '#{config.kernel}'"
                descr_changed = true
                kernel.text = config.kernel
              end
            end
          end
          if config.initrd
            initrd = REXML::XPath.first(xml_descr, '/domain/os/initrd')
            if initrd.nil?
              if config.initrd.strip != ''
                @logger.debug "initrd updated from not set to '#{config.initrd}'"
                descr_changed = true
                initrd = REXML::Element.new('initrd', REXML::XPath.first(xml_descr, '/domain/os'))
                initrd.text = config.initrd
              end
            else
              if (initrd.text or '').strip != config.initrd
                @logger.debug "initrd updated from '#{initrd.text}' to '#{config.initrd}'"
                descr_changed = true
                initrd.text = config.initrd
              end
            end
          end

          loader = REXML::XPath.first(xml_descr, '/domain/os/loader')
          if config.loader
            if loader.nil?
              descr_changed = true
              loader = REXML::Element.new('loader')
              REXML::XPath.first(xml_descr, '/domain/os').insert_after('//type', loader)
              loader.text = config.loader
            else
              if (loader.text or '').strip != config.loader
                descr_changed = true
                loader.text = config.loader
              end
            end
            loader.attributes['type'] = config.nvram ? 'pflash' : 'rom'
          elsif !loader.nil?
            descr_changed = true
            loader.parent.delete_element(loader)
          end

          nvram = REXML::XPath.first(xml_descr, '/domain/os/nvram')
          if config.nvram
            if nvram.nil?
              descr_changed = true
              nvram = REXML::Element.new('nvram')
              REXML::XPath.first(xml_descr, '/domain/os').insert_after(loader, nvram)
              nvram.text = config.nvram
            else
              if (nvram.text or '').strip != config.nvram
                descr_changed = true
                nvram.text = config.nvram
              end
            end
          elsif !nvram.nil?
            descr_changed = true
            nvram.parent.delete_element(nvram)
          end

          # Apply
          if descr_changed
            env[:ui].info(I18n.t('vagrant_libvirt.updating_domain'))
            new_xml = String.new
            xml_descr.write(new_xml)
            begin
              # providing XML for the same name and UUID will update the existing domain
              libvirt_domain = env[:machine].provider.driver.connection.define_domain(new_xml)
            rescue ::Libvirt::Error => e
              env[:ui].error("Error when updating domain settings: #{e.message}")
              raise Errors::UpdateServerError, error_message: e.message
            end

            # this normalises the attribute order to be the same as what was sent in the above
            # request to update the domain XML. Without this, if the XML documents are not
            # equivalent, many more differences will be reported than there actually are.
            applied_xml = String.new
            REXML::Document.new(libvirt_domain.xml_desc(1)).write(applied_xml)

            # need to check whether the updated XML contains all the changes requested
            proposed = VagrantPlugins::ProviderLibvirt::Util::Xml.new(new_xml)
            applied = VagrantPlugins::ProviderLibvirt::Util::Xml.new(applied_xml)

            # perform some sorting to allow comparison otherwise order of devices differing
            # even if they are equivalent will be reported as being different.
            proposed.xml['devices'][0].each { |_, v| next unless v.is_a?(Array); v.sort_by! { |e| [e['type'], e['index']]} }
            applied.xml['devices'][0].each { |_, v| next unless v.is_a?(Array); v.sort_by! { |e| [e['type'], e['index']]} }

            if proposed != applied
              require 'diffy'

              diff = Diffy::Diff.new(proposed.to_str, applied.to_str, :context => 3).to_s(:text)

              error_msg = "Libvirt failed to fully update the domain with the specified XML. Result differs from requested:\n" +
                "--- requested\n+++ result\n#{diff}\n" +
                "Typically this means there is a bug in the XML being sent, please log an issue as this will halt machine start in the future."

              env[:ui].warn(error_msg)
              #env[:ui].error("Updated domain settings did not fully apply, attempting restore to previous definition: #{error_msg}")
              #begin
              #  env[:machine].provider.driver.connection.define_domain(descr)
              #rescue Fog::Errors::Error => e
              #  env[:ui].error("Failed to restore previous domain definition: #{e.message}")
              #end

              #raise Errors::UpdateServerError, error_message: error_msg
            end
          end

          begin
            # Autostart with host if enabled in Vagrantfile
            libvirt_domain.autostart = config.autostart
            @logger.debug {
              "Starting Domain with XML:\n#{libvirt_domain.xml_desc}"
            }
            # Actually start the domain
            env[:ui].info(I18n.t('vagrant_libvirt.starting_domain'))
            domain.start
          rescue Fog::Errors::Error, Errors::VagrantLibvirtError => e
            raise Errors::DomainStartError, error_message: e.message
          end

          #libvirt_domain = env[:machine].provider.driver.connection.client.lookup_domain_by_uuid(env[:machine].id)
          xmldoc = REXML::Document.new(libvirt_domain.xml_desc)
          graphics = REXML::XPath.first(xmldoc, '/domain/devices/graphics')

          if !graphics.nil?
            if config.graphics_autoport
              env[:ui].info(I18n.t('vagrant_libvirt.starting_domain_with_graphics'))
              env[:ui].info(" -- Graphics Port:      #{graphics.attributes['port']}")
              env[:ui].info(" -- Graphics IP:        #{graphics.attributes['listen']}")
              env[:ui].info(" -- Graphics Password:  #{config.graphics_passwd.nil? ? 'Not defined' : 'Defined'}")
            end

            if config.graphics_websocket == -1
              env[:ui].info(" -- Graphics Websocket: #{graphics.attributes['websocket']}")
            end
          end

          @app.call(env)
        end
      end
    end
  end
end
