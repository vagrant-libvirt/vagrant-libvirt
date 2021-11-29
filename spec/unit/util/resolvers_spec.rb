# frozen_string_literal: true

require 'spec_helper'

require 'vagrant-libvirt/util/resolvers'

describe VagrantPlugins::ProviderLibvirt::Util::DiskDeviceResolver do
  subject { described_class.new }

  def deep_clone_disks(disk_array)
    new_array = []
    disk_array.each do |disk|
      new_array.push disk.dup
    end

    new_array
  end

  describe '#resolve!' do
    context 'when using default prefix' do
      [
        [
          [{:name => 'single-disk'}],
          [{:name => 'single-disk', :device => 'vda'}],
        ],
        [
          [{:name => 'disk1'}, {:name => 'disk2'}],
          [{:name => 'disk1', :device => 'vda'}, {:name => 'disk2', :device => 'vdb'}],
        ],
        [
          [{:name => 'disk1'}, {:name => 'disk2', :device => 'vdc'}],
          [{:name => 'disk1', :device => 'vda'}, {:name => 'disk2', :device => 'vdc'}],
        ],
        [
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2', :device => 'vda'}],
        ],
      ].each do |input_disks, output_disks, options={}|
        opts = {}.merge!(options)
        it "should handle inputs: #{input_disks}" do
          disks = deep_clone_disks(input_disks)
          expect(subject.resolve!(disks)).to eq(output_disks)
          expect(disks).to_not eq(input_disks)
        end
      end
    end

    context 'when using different default prefix' do
      let(:subject) { described_class.new('sd') }
      [
        [
          [{:name => 'single-disk'}],
          [{:name => 'single-disk', :device => 'sda'}],
        ],
        [
          [{:name => 'disk1'}, {:name => 'disk2'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2', :device => 'sdb'}],
        ],
        [
          [{:name => 'disk1'}, {:name => 'disk2', :device => 'vdc'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2', :device => 'vdc'}],
        ],
        [
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2', :device => 'sdb'}],
        ],
        [
          [{:name => 'disk1'}, {:name => 'disk2', :device => 'sda'}],
          [{:name => 'disk1', :device => 'sdb'}, {:name => 'disk2', :device => 'sda'}],
        ],
      ].each do |input_disks, output_disks, options={}|
        opts = {}.merge!(options)
        it "should handle inputs: #{input_disks}" do
          disks = deep_clone_disks(input_disks)
          expect(subject.resolve!(disks)).to eq(output_disks)
        end
      end
    end

    context 'when using custom prefix' do
      [
        [
          [{:name => 'existing-disk', :device => 'vda'}],
          [{:name => 'single-disk'}],
          [{:name => 'single-disk', :device => 'sda'}],
          {:prefix => 'sd'},
        ],
        [
          [{:name => 'existing-disk', :device => 'vda'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2'}],
          [{:name => 'disk1', :device => 'sda'}, {:name => 'disk2', :device => 'sdb'}],
          {:prefix => 'sd'},
        ],
      ].each do |existing, input_disks, output_disks, options={}|
        opts = {}.merge!(options)
        it "should handle inputs: #{input_disks} with opts: #{opts}" do
          disks = deep_clone_disks(input_disks)
          subject.resolve(existing)
          expect(subject.resolve!(disks, opts)).to eq(output_disks)
        end
      end
    end
  end

  describe '#resolve' do
    let(:input_disks) { [{:name => 'single-disk'}] }
    let(:output_disks) { [{:name => 'single-disk', :device => 'vda'}] }

    it "should resolve without modifying" do
      disks = deep_clone_disks(input_disks)
      expect(subject.resolve(disks)).to eq(output_disks)
      expect(disks).to_not eq(output_disks)
      expect(disks).to eq(input_disks)
    end
  end
end
