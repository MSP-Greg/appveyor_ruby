# frozen_string_literal: true
# encoding: UTF-8

# Copyright (C) 2017 MSP-Greg

module Msys2Info

  YELLOW = "\e[33m"
  RESET = "\e[0m"

  class << self
    def run
      case ARGV[0]
      when 'utf-8'
        d4 = "\u2015".dup.force_encoding('utf-8') * 4
      when 'Windows-1252'
        d4 = 151.chr * 4
      else
        d4 = "\u2015".dup.force_encoding('utf-8') * 4
      end

      ary = `bash -lc "pacman -Q"`

      hsh = ary.split(/[\r\n]+/).group_by { |e|
        case e
        when /\Amingw-w64-i686-/   then :i686
        when /\Amingw-w64-x86_64-/ then :x64
        else :msys2
        end
      }

      hsh[:i686]   = [] unless hsh[:i686]
      hsh[:x64]    = [] unless hsh[:x64]
      hsh[:msys2]  = [] unless hsh[:msys2]

      unless hsh[:i686].empty? && hsh[:x64].empty?
        highlight "\n#{(d4 + ' mingw-w64-x86_64 Packages ' + d4).ljust(59)} #{d4} mingw-w64-i686 Packages #{d4}"
        max_len = [hsh[:i686].length, hsh[:x64].length].max - 1
        x, i = 0,0
        0.upto(max_len) { |j|
          # get package base name
          x64  = hsh[:x64][x]  ? (hsh[:x64][x]  || '').split(' ')[0].split('-').last : ''
          i686 = hsh[:i686][i] ? (hsh[:i686][i] || '').split(' ')[0].split('-').last : ''
          if x64 != i686
            if x64 == hsh[:i686][i+1] ? (hsh[:i686][i+1] || '').split(' ')[0].split('-').last : '' 
              puts "#{(hsh[:x64][x] || '')}"
              i -= 1
            elsif i686 == hsh[:x64][x+1] ? (hsh[:x64][x+1]  || '').split(' ')[0].split('-').last : ''
              puts "#{''.ljust(59)} #{hsh[:i686][i] || ''}"        
              x -= 1
            end
          else
            puts "#{(hsh[:x64][x] || '').ljust(59)} #{hsh[:i686][i] || ''}"
          end
          x += 1 ; i += 1
        }
      end

      unless hsh[:msys2].empty?
        highlight "\n#{(d4 + ' MSYS2 Packages ' + d4).ljust(59)} #{d4} MSYS2 Packages #{d4}"
        half = hsh[:msys2].length/2.ceil
        0.upto(half -1) { |i|
          puts "#{(hsh[:msys2][i] || '').ljust(59)} #{hsh[:msys2][i + half] || ''}"
        }
      end
    end
    
    def highlight(str)
      puts "#{YELLOW}#{str}#{RESET}"
    end

  end
end
Msys2Info.run

exit 0
