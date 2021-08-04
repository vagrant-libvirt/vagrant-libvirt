# frozen_string_literal: true

require 'log4r'
require 'rexml/document'

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
          env[:ui].info(I18n.t('vagrant_libvirt.starting_domain'))

          domain = env[:machine].provider.driver.connection.servers.get(env[:machine].id.to_s)
          raise Errors::NoDomainError if domain.nil?
          config = env[:machine].provider_config

          begin
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
            begin
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

              # Iterface type
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
                  @logger.debug "cpu_model updated from not set to '#{config.cpu_model}'"
                  descr_changed = true
                  cpu_model = REXML::Element.new('model', REXML::XPath.first(xml_descr, '/domain/cpu'))
                  cpu_model.attributes['fallback'] = 'allow'
                  cpu_model.text = config.cpu_model
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

              # Clock
              clock = REXML::XPath.first(xml_descr, '/domain/clock')
              if clock.attributes['offset'] != config.clock_offset
                @logger.debug "clock offset changed"
                descr_changed = true
                clock.attributes['offset'] = config.clock_offset
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
                if graphics.attributes['autoport'] != config.graphics_autoport
                  descr_changed = true
                  graphics.attributes['autoport'] = config.graphics_autoport
                  if config.graphics_autoport == 'no'
                    graphics.attributes['port'] = config.graphics_port
                  end
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
              else
                # graphics_type = none, remove entire element
                graphics.parent.delete_element(graphics) unless graphics.nil?
              end

              # TPM
              if [config.tpm_path, config.tpm_version].any?
                if config.tpm_path
                  raise Errors::FogCreateServerError, 'The TPM Path must be fully qualified' unless config.tpm_path[0].chr == '/'
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
                  @logger.debug "initrd updated from not set to '#{config.initrd}'"
                  descr_changed = true
                  initrd = REXML::Element.new('initrd', REXML::XPath.first(xml_descr, '/domain/os'))
                  initrd.text = config.initrd
                else
                  if (initrd.text or '').strip != config.initrd
                    @logger.debug "initrd updated from '#{initrd.text}' to '#{config.initrd}'"
                    descr_changed = true
                    initrd.text = config.initrd
                  end
                end
              end

              # Apply
              if descr_changed
                begin
                  libvirt_domain.undefine
                  new_descr = String.new
                  xml_descr.write new_descr
                  env[:machine].provider.driver.connection.servers.create(xml: new_descr)
                rescue Fog::Errors::Error => e
                  env[:machine].provider.driver.connection.servers.create(xml: descr)
                  raise Errors::FogCreateServerError, error_message: e.message
                end
              end
            rescue Errors::VagrantLibvirtError => e
              env[:ui].error("Error when updating domain settings: #{e.message}")
            end
            # Autostart with host if enabled in Vagrantfile
            libvirt_domain.autostart = config.autostart
            # Actually start the domain
            domain.start
          rescue Fog::Errors::Error, Errors::VagrantLibvirtError => e
            raise Errors::FogError, message: e.message
          end

          @app.call(env)
        end
      end
    end
  end
end
