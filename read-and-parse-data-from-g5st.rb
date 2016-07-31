#!/usr/bin/env ruby
# coding: utf-8
#
# read and parse data from PLANTOWER G5ST(PMS5003ST) sensor
#
# (sudo) gem install serialport
#
require 'rubygems'
require 'serialport'


ports = Dir[ '/dev/tty.usb*' ]
if ports.empty?
  puts ' Please connect ttl2usb adpater first'
  exit 1
end

port = ports.first
begin
  puts "#{Time.now.strftime('%F_%T')} Started Here: ..."
  sp = SerialPort.new port, 9600, 8, 1, 0

  structure_seq = [
      # 'START_CHAR1', # 0x42, B
      # 'START_CHAR2', # 0x4d, M
      # '帧长高8位', #'FRAME_H8',  # 0
      # '帧长低8位', #'FRAME_L8',  # 36 = 2 * 17 + 2
      '工业PM1.0高8位', #'01_SPM010_H8', # 0, PM 1.0
      '工业PM1.0低8位', #'01_SPM010_L8', # 45
      '工业PM2.5高8位', #'02_SPM025_H8', # 0, PM 2.5
      '工业PM2.5低8位', #'02_SPM025_L8', # 60
      '工业PM10高8位', #'03_SPM100_H8', # 0, PM 10
      '工业PM10低8位', #'03_SPM100_L8', # 70
      '家用PM1.0高8位', #'04_APM010_H8', # 0
      '家用PM1.0低8位', #'04_APM010_L8', # 32
      '家用PM2.5高8位', #'05_APM025_H8', # 0
      '家用PM2.5低8位', #'05_APM025_L8', # 45
      '家用PM10高8位', #'06_APM100_H8', # 0
      '家用PM10低8位', #'06_APM100_L8', # 59
      '0.3um以上颗粒个数高8位', #'07_003UM_H8', # 25, 0.3um in 0.1^3 m Air
      '0.3um以上颗粒个数低8位', #'07_003UM_L8', # 182
      '0.5um以上颗粒个数高8位', #'08_005UM_H8', # 7
      '0.5um以上颗粒个数低8位', #'08_005UM_L8', # 140
      '1.0um以上颗粒个数高8位', #'09_010UM_H8', # 1
      '1.0um以上颗粒个数低8位', #'09_010UM_L8', # 44
      '2.5um以上颗粒个数高8位', #'10_025UM_H8', # 0
      '2.5um以上颗粒个数低8位', #'10_025UM_L8', # 29
      '5.0um以上颗粒个数高8位', #'11_050UM_H8', # 0
      '5.0um以上颗粒个数低8位', #'11_050UM_L8', # 10
      '10um以上颗粒个数高8位', #'12_100UM_H8', # 0
      '10um以上颗粒个数低8位', #'12_100UM_L8', # 2
      '甲醛浓度高8位', #'13_VOC_H8', # 0
      '甲醛浓度低8位', #'13_VOC_L8', # 24, * 1/1000
      '温度高8位', #'14_TEMP_H8', # 0
      '温度低8位', #'14_TEMP_L8', # 247, * 1/10, C
      '湿度高8位', #'15_MOSI_H8', # 2
      '湿度低8位', #'15_MOSI_L8', # 35, * 1/10
      '保留位高8位', # 16_RESERVE_H8, # 0
      '保留位低8位', # 16_RESERVE_L8, # 0, reserved
      '版本号',  # 17_VERSION, # 114
      '错误码', # 17_ERRCODE, # 0
      'CHECKSUM_H8', # 5
      'CHECKSUM_L8'  # 72
  ]

  human_seq = [
      '工业PM1.0',
      '工业PM2.5',
      '工业PM10',
      '家用PM1.0',
      '家用PM2.5',
      '家用PM10',
      '0.3um以上颗粒个数',
      '0.5m以上颗粒个数',
      '1.0um以上颗粒个数',
      '2.5um以上颗粒个数',
      '5.0um以上颗粒个数',
      '10um以上颗粒个数',
      '甲醛浓度',
      '温度',
      '湿度',
      '16_RESE_H8',
      '16_RESE_L8',
      '17_VERSION',
      '17_ERRCODE',
      'SUM_H8',
      'SUM_L8'
  ]

  formalin    = human_seq.find_index '甲醛浓度'
  temperature = human_seq.find_index '温度'
  mositure    = human_seq.find_index '湿度'

  puts ' Waiting data ...'
  readin = sp.each_byte
  readin.each do | byte |
    if byte == 0x42
      puts Time.now.strftime( '%F_%T')
      next_byte = sp.getbyte
      if next_byte == 0x4d
        #puts " Found START_CHAR1 #{byte.to_s(16)}, START_CHAR2: #{next_byte.to_s(16)} "
        frame_h8 = sp.readbyte
        frame_l8 = sp.readbyte
        frame_length = ( frame_h8 << 8 ) + frame_l8
        puts " frame_length: #{frame_length}"
        data = sp.read( frame_length ) # 36 = 2 * 17 + 2
        if data.nil?
          puts ' data is nil, must be worng. ignore me'
        else
          human_pretty_data = {}
          #puts "RAW format, class: #{data.class} => #{data}"
          check_sum   = 0x42 + 0x4d + frame_h8 + frame_l8
          high_bit    = true
          #pretty_data = {}
          last_value  = nil
          data_array  = data.chars
          check_sum_readed = ( data_array[-2].ord << 8 ) + data_array[-1].ord
          puts " Read #{data_array.count} bytes, and check_sum #{check_sum_readed}"
          # puts " #{data_array[9].ord}, #{data_array[25].ord}, #{data_array[27].ord}, #{data_array[29].ord}"
          data_array.each_index do | x |
            value = data_array[x].ord
            # checksum will ignore last 2 bytes
            if x < frame_length - 2
              check_sum = check_sum + value

              # last 6 bytes format != high 8 bit + low 8 bit
              if x < frame_length - 6
                if high_bit
                  last_value = value
                else
                  value      = ( last_value << 8 ) + value
                  last_value = nil
                  index_in_human = x / 2
                  case index_in_human
                    when formalin
                      value = format( '%.4f', value / 1000.0 ).to_f
                    when temperature
                      value = format( '%.1f', value / 10.0 ).to_f + 3
                    when mositure
                      value = format( '%.1f', value / 10.0 ).to_f
                  end
                  human_pretty_data[ human_seq[index_in_human]] = value
                end
                high_bit = !high_bit
              end
            end
            #pretty_data[structure_seq[x].to_sym ] = value
          end
          # pretty_data.delete_if { |k,v| v == 0 }
          # puts pretty_data
          if check_sum == check_sum_readed
            puts human_pretty_data.inspect
          else
            puts " check_sum: #{check_sum} != check_sum_readed: #{check_sum_readed}, ignore me"
          end
        end
      else
        puts " Bad sequence, met #{next_byte} after 0x42, shoud be 0x4d"
      end
    end
  end
end
