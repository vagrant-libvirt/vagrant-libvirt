# frozen_string_literal: true

require 'spec_helper'

require 'vagrant-libvirt/util/byte_number'


describe ByteNumber do
  describe '#ByteNumber to Gigrabyte' do
    it 'should return bigger size' do
      expect( ByteNumber.new("10737423360").to_GB).to eq(11)
      expect( ByteNumber.new("737423360").to_GB).to eq(1)
      expect( ByteNumber.new("110737423360").to_GB).to eq(104)
    end
  end

  describe '#ByteNumber from Gigrabyte' do
    it 'should convert' do
      expect( ByteNumber.from_GB(5).to_i).to eq(5368709120)
    end
  end

  describe '#ByteNumber pow' do
    it 'should be work like interger' do
      expect( ByteNumber.new(5).pow(5).to_i).to eq(5**5)
    end
  end
end
