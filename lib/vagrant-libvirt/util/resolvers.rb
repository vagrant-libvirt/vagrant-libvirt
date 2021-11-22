# frozen_string_literal: true

require 'log4r'

require 'vagrant-libvirt/errors'

module VagrantPlugins
  module ProviderLibvirt
    module Util
      class DiskDeviceResolver
        attr_reader :existing

        def initialize(prefix='vd')
          @default_prefix = prefix

          @device_indicies = Hash.new
          @existing = Hash.new
        end

        def resolve!(disks, options={})
          # check for duplicate device entries and raise an exception if one found
          # with enough details that the user should be able to determine what
          # to do to resolve.
          disks.select { |x| !x[:device].nil? }.each do |x|
            if @existing.has_key?(x[:device])
              raise Errors::DuplicateDiskDevice, new_disk: x, existing_disk: @existing[x[:device]]
            end

            @existing[x[:device]] = x
          end

          disks.each_index do |index|
            dev = disks[index][:device]
            if dev.nil?
              prefix = options.fetch(:prefix, @default_prefix)
              dev = next_device(prefix=prefix)
              if dev.nil?
                raise Errors::NoDiskDeviceAvailable, prefix: prefix
              end

              disks[index][:device] = dev
              @existing[dev] = disks[index]
            end
          end
        end

        def resolve(disks)
          new_disks = []
          disks.each do |disk|
            new_disks.push disk.dup
          end

          resolve!(new_disks)

          new_disks
        end

        private

        def next_device(prefix)
          curr = device_index(prefix)
          while curr <= 'z'.ord
            dev = prefix + curr.chr
            if !@existing[dev].nil?
              curr += 1
              next
            else
              @device_indicies[prefix] = curr
              return dev
            end
          end
        end

        def device_index(prefix)
          @device_indicies[prefix] ||= 'a'.ord
        end
      end
    end
  end
end
