# frozen_string_literal: true
# encoding: UTF-8

# Copyright (C) 2017 MSP-Greg

require "rbconfig" unless defined? RbConfig

module VersInfo

  YELLOW = "\e[33m"
  RESET = "\e[0m"

  @@col_wid = [34, 14, 17, 26, 10, 16]

  case ARGV[0]
  when 'utf-8'
    @@dash = "\u2015".dup.force_encoding 'utf-8'
  when 'Windows-1252'
    @@dash = 151.chr
  else
    @@dash = "\u2015".dup.force_encoding 'utf-8'
  end

  class << self

    def run
      gem 'psych' if (ENV['APPVEYOR'] && RUBY_VERSION < '2.0')

      # Give AV build a title that means something
      if /trunk/ =~ RUBY_DESCRIPTION && Dir.exist?('C:/Users/appveyor') && ENV['APPVEYOR']
        title = "#{Time.now.utc.strftime('%F %R UTC')}   #{RUBY_DESCRIPTION[/\([^\)]+\)/]}"
        `appveyor UpdateBuild -Message \"#{title}\"`
      end

      puts RUBY_DESCRIPTION
      puts
      puts "Build Type/Info: #{ri2_vers}"
      gcc = RbConfig::CONFIG["CC_VERSION_MESSAGE"] ?
        RbConfig::CONFIG["CC_VERSION_MESSAGE"][/\A.+?\n/].strip : 'unknown'
      puts "       gcc info: #{gcc}"
      puts
      first('rubygems'  , 'Gem::VERSION'  , 2)  { Gem::VERSION     }
      puts
      first('bigdecimal', 'BigDecimal.ver', 2)  {
        BigDecimal.const_defined?(:VERSION) ? BigDecimal::VERSION : BigDecimal.ver
      }
      first('gdbm'      , 'GDBM::VERSION' , 2)  { GDBM::VERSION    }
      first('json/ext'  , 'JSON::VERSION' , 2)  { JSON::VERSION    }
      puts

      if first('openssl', 'OpenSSL::VERSION', 0) { OpenSSL::VERSION }
        additional('SSL Verify'             , 0, 4) { ssl_verify }
        additional('OPENSSL_VERSION'        , 0, 4) { OpenSSL::OPENSSL_VERSION }
        if OpenSSL.const_defined?(:OPENSSL_LIBRARY_VERSION)
          additional('OPENSSL_LIBRARY_VERSION', 0, 4) { OpenSSL::OPENSSL_LIBRARY_VERSION }
        else
          additional('OPENSSL_LIBRARY_VERSION', 0, 4) { "Not Defined" }
        end
        ssl_methods
        puts
        additional_file('X509::DEFAULT_CERT_FILE'    , 0, 4) { OpenSSL::X509::DEFAULT_CERT_FILE }
        additional_file('X509::DEFAULT_CERT_DIR'     , 0, 4) { OpenSSL::X509::DEFAULT_CERT_DIR }
        additional_file('Config::DEFAULT_CONFIG_FILE', 0, 4) { OpenSSL::Config::DEFAULT_CONFIG_FILE }
        puts
        additional_file("ENV['SSL_CERT_FILE']"       , 0, 4) { ENV['SSL_CERT_FILE'] }
        additional_file("ENV['SSL_CERT_DIR']"        , 0, 4) { ENV['SSL_CERT_DIR']  }
        additional_file("ENV['OPENSSL_CONF']"        , 0, 4) { ENV['OPENSSL_CONF']  }
      end
      puts

      double('psych', 'Psych::VERSION', 'LIBYAML_VERSION', 3, 1, 2) { [Psych::VERSION, Psych::LIBYAML_VERSION] }
      require 'readline'
      @rl_type = (Readline.method(:line_buffer).source_location ? 'rb' : 'so')
      first('readline', "Readline::VERSION (#{@rl_type})", 3) { Readline::VERSION }
      double('zlib', 'Zlib::VERSION', 'ZLIB_VERSION', 3, 1, 2) { [Zlib::VERSION, Zlib::ZLIB_VERSION] }

      if const_defined?(:Integer)
        puts Integer.const_defined?(:GMP_VERSION) ?
          "#{'Integer::GMP_VERSION'.ljust(@@col_wid[3])}#{Integer::GMP_VERSION}" :
          "#{'Integer::GMP_VERSION'.ljust(@@col_wid[3])}Unknown"
      elsif const_defined?(:Bignum)
        puts Bignum.const_defined?(:GMP_VERSION) ?
          "#{'Bignum::GMP_VERSION'.ljust( @@col_wid[3])}#{Bignum::GMP_VERSION}" :
          "#{'Bignum::GMP_VERSION'.ljust( @@col_wid[3])}Unknown"
      end

      highlight "\n#{@@dash * 5} CLI Test #{@@dash * 17}    #{@@dash * 5} Require Test #{@@dash * 39}"
      puts chk_cli("bundle -v", /\ABundler version (\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9]+)?)/) +
        loads2('dbm'     , 'DBM'     , 'win32/registry', 'Win32::Registry', 4)

      puts chk_cli("gem --version", /\A(\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9]+)?)/) +
        loads2('digest'  , 'Digest'  , 'win32ole'      , 'WIN32OLE'       , 4)

      puts chk_cli("rake -V", /\Arake, version (\d{1,2}\.\d{1,2}\.\d{1,2}(\.[a-z0-9]+)?)/) +
        loads2('fiddle'  , 'Fiddle'  , 'zlib'          , 'Zlib'           , 4)
      puts (' ' * 36) + loads1('socket' , 'Socket' , 4)

      gem_list
    end

  private

    def ri2_vers
      fn = "#{RbConfig::TOPDIR}/lib/ruby/site_ruby/#{RbConfig::CONFIG['ruby_version']}/ruby_installer/runtime/package_version.rb"
      if File.exist?(fn)
        s = File.read(fn)
        "RubyInstaller2 vers #{s[/^ *PACKAGE_VERSION *= *['"]([^'"]+)/, 1].strip}  commit #{s[/^ *GIT_COMMIT *= *['"]([^'"]+)/, 1].strip}"
      else
        "RubyInstaller build?"
      end
    end

    def loads1(req, str, idx)
      require req
      "#{str.ljust(15)}  Ok"
    rescue LoadError
      "#{str.ljust(15)}  Does not load!"
    end

    def loads2(req1, str1, req2, str2, idx)
      begin
        require req1
        str = "#{str1.ljust(15)}  Ok            "
      rescue LoadError
        str = "#{str1.ljust(15)}  LoadError     "
      end
      begin
        require req2
        str + "#{str2.ljust(15)}  Ok"
      rescue LoadError
        str + "#{str2.ljust(15)}  LoadError"
      end
    end

    def first(req, text, idx)
      col = idx > 10 ? idx : @@col_wid[idx]
      require req
      puts "#{text.ljust(col)}#{yield}"
      true
    rescue LoadError
      puts "#{text.ljust(col)}NOT FOUND!"
      false
    end

    def additional(text, idx, indent = 0)
      fn = yield
      puts "#{(' ' * indent + text).ljust(@@col_wid[idx])}#{fn}"
    rescue LoadError
    end

    def additional_file(text, idx, indent = 0)
      fn = yield
      if fn.nil?
        found = 'No ENV key'
      elsif /\./ =~ File.basename(fn)
        found = File.exist?(fn) ?
          "#{File.mtime(fn).utc.strftime('File Dated %F').ljust(23)}#{fn}" :
          "#{'File Not Found!'.ljust(23)}Unknown path or file"
      else
        found = Dir.exist?(fn) ?
          "#{'Dir  Exists'.ljust(23)}#{fn}" :
          "#{'Dir  Not Found!'.ljust(23)}Unknown path or file"
      end
      puts "#{(' ' * indent + text).ljust(@@col_wid[idx])}#{found}"
    rescue LoadError
    end

    def env_file_exists(env)
      if fn = ENV[env]
        if /\./ =~ File.basename(fn)
          "#{ File.exist?(fn) ? "#{File.mtime(fn).utc.strftime('File Dated %F')}" : 'File Not Found!      '}  #{fn}"
        else
          "#{(Dir.exist?(fn) ? 'Dir  Exists' : 'Dir  Not Found!').ljust(23)}  #{fn}"
        end
      else
        "none"
      end
    end

    def double(req, text1, text2, idx1, idx2, idx3)
      require req
      val1, val2 = yield
      puts "#{text1.ljust(@@col_wid[idx1])}#{val1.ljust(@@col_wid[idx2])}" \
           "#{text2.ljust(@@col_wid[idx3])}#{val2}"
    rescue LoadError
      puts "#{text1.ljust(@@col_wid[idx1])}NOT FOUND!"
    end

    def gem_list
      require "rubygems/commands/list_command"
      sio_in, sio_out, sio_err = StringIO.new, StringIO.new, StringIO.new
      strm_io = Gem::StreamUI.new(sio_in, sio_out, sio_err, false)
      cmd = Gem::Commands::ListCommand.new
      orig_ui = cmd.ui
      cmd.ui = strm_io
      cmd.execute
      ary = sio_out.string.split(/\r*\n/)
      cmd.ui = orig_ui

      ary_bundled = []
      ary_default = []

      ary.each { |s|
        gem_name = s[/\A[^ ]+/]
        is_default = false
        all_vers = ''.dup
        cnt_vers = 0
        s.scan(/(default: |\(|, )(\d+\.\d+[^,)]*)/) { |type, vers|
          if type == 'default: '
            is_default ||= true
          end
          all_vers += " #{vers}"
          cnt_vers += 1
        }
        if is_default
          ary_default << [gem_name, all_vers.strip, cnt_vers]
        else
          ary_bundled << [gem_name, all_vers.strip, cnt_vers]
        end
      }
      highlight "\n#{@@dash * 23} #{"Default Gems #{@@dash * 5}".ljust(27)} #{@@dash * 23} Bundled Gems #{@@dash * 5}"

      max_rows = [ary_default.length || 0, ary_bundled.length || 0].max
      (0..(max_rows-1)).each { |i|
        dflt = ary_default[i] ? ary_default[i] : ["", "", 0]
        bndl = ary_bundled[i] ? ary_bundled[i] : nil

        str_dflt = "#{dflt[1].rjust(23)} #{dflt[0].ljust(27)}"
        str_bndl = bndl ? "#{bndl[1].rjust(23)} #{bndl[0]}" : ''

        puts bndl ? "#{str_dflt} #{str_bndl}".rstrip : "#{str_dflt}".rstrip
      }
    ensure
      sio_in.close
      sio_out.close
      sio_err.close
      strm_io = nil
      cmd = nil
    end

    def ssl_methods
      ssl = OpenSSL::SSL
      if RUBY_VERSION < '2.0'
        additional('SSLContext::METHODS', 0, 4) {
          ssl::SSLContext::METHODS.reject { |e| /client|server/ =~ e }.sort.join(' ')
        }
      else
        require_relative 'ssl_test'
        additional('Available Protocols', 0, 4) {
          TestSSL.check_supported_protocol_versions
        }
      end
    end

    def ssl_verify
      require 'net/http'
      uri = URI.parse('https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess')
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_PEER) { |https|
        Net::HTTP::Get.new uri
      }
      "Success"
    rescue SocketError
      "*** UNKNOWN - internet connection failure? ***"
    rescue OpenSSL::SSL::SSLError # => e
      "*** FAILURE ***"
    end

    def chk_cli(cmd, regex)
      wid = 36
      cmd_str = cmd[/\A[^ ]+/].ljust(10)
      require 'open3'
      ret = ''.dup
      Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
        ret = stdout.read.strip
      }
      ret[regex] ? "#{cmd_str}Ok   #{$1}".ljust(wid) : "#{cmd_str}No version?".ljust(wid)
    rescue
      "#{cmd_str}Missing or incorrect bin".ljust(wid)
    end

    def highlight(str)
      if RUBY_VERSION >= '2.0' || ENV.key?('APPVEYOR')
        str2 = str.dup
        while str2.sub!(/\A\n/, '') do ; puts ; end
        puts "#{YELLOW}#{str2}#{RESET}"
      else
        puts str
      end
    end

  end
end

VersInfo.run ; exit 0
