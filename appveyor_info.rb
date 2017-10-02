require "rbconfig"

module VersInfo
  @@col_wid = [34, 14, 17, 26, 10, 16]

  @@dash = 8212.chr(Encoding::UTF_8)

  class << self

    def run
      # Give AV build a title that means something
      if /trunk/ =~ RUBY_DESCRIPTION && Dir.exist?('C:/Users/appveyor') && Dir.exist?('C:/Program Files/AppVeyor/BuildAgent')
        title = "#{Time.now.utc.strftime('%F %R UTC')}   #{RUBY_DESCRIPTION[/\([^\)]+\)/]}"
        `appveyor UpdateBuild -Message \"#{title}\"`
      end

      puts " #{Time.now.getutc}     Appveyor Ruby #{RUBY_VERSION}".rjust(110, @@dash)
      puts
      puts RUBY_DESCRIPTION
      puts
      puts "Build Type/Info: #{ri2_vers}"
      gcc = RbConfig::CONFIG["CC_VERSION_MESSAGE"] ?
        RbConfig::CONFIG["CC_VERSION_MESSAGE"][/\A.+?\n/].strip : 'unknown'
      puts "       gcc info: #{gcc}"
      puts
      first('rubygems'  , 'Gem::VERSION'  , 2)  { Gem::VERSION     }
      puts
      first('bigdecimal', 'BigDecimal.ver', 2)  { BigDecimal.ver   }
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

      if const_defined?(:Integer) &&  Integer.const_defined?(:GMP_VERSION)
        puts "#{'Integer::GMP_VERSION'.ljust(@@col_wid[3])}#{Integer::GMP_VERSION}"
      elsif const_defined?(:Bignum)
        if Bignum.const_defined?(:GMP_VERSION)
          puts "#{'Bignum::GMP_VERSION'.ljust( @@col_wid[3])}#{Bignum::GMP_VERSION}"
        else
          puts "#{'Bignum::GMP_VERSION'.ljust( @@col_wid[3])}Unknown"
        end
      end
      puts "\n#{@@dash * 56} Load Test"
      loads2?('dbm'     , 'DBM'     , 'socket'        , 'Socket'         , 4)
      loads2?('digest'  , 'Digest'  , 'win32/registry', 'Win32::Registry', 4)
      loads2?('fiddle'  , 'Fiddle'  , 'win32ole'      , 'WIN32OLE'       , 4)
      loads1?('zlib'    , 'Zlib', 4, chk_rake(4))

      gem_list
      puts "\n#{@@dash * 110}"
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

    def chk_rake(idx)
      require 'open3'
      ret = String.new
      Open3.popen3("rake -V") {|stdin, stdout, stderr, wait_thr|
        ret = stdout.read.strip
      }
      if /\d+\.\d+\.\d+/ =~ ret
        "#{'Rake CLI'.ljust(@@col_wid[idx])}  Ok".ljust(@@col_wid[0])
      else
        "#{'Rake CLI'.ljust(@@col_wid[idx])}  Does not load!".ljust(@@col_wid[0])
      end
    rescue
      "#{'Rake CLI'.ljust(@@col_wid[idx])}  Does not load!".ljust(@@col_wid[0])
    end
    
    def loads1?(req, str, idx, pref = nil)
      begin
        require req
        if pref
          puts "#{pref}#{str.ljust(@@col_wid[idx+1])}  Ok"
        else
          puts "#{str.ljust(@@col_wid[idx])}  Ok"
        end
      rescue LoadError
        if pref
          puts "#{pref}#{str.ljust(@@col_wid[idx]+1)}  Does not load!"
        else
          puts "#{str.ljust(@@col_wid[idx])}  Does not load!"
        end
      end
    end

    def loads2?(req1, str1, req2, str2, idx)
      begin
        require req1
        str = "#{str1.ljust(@@col_wid[idx])}  Ok".ljust(@@col_wid[0])
      rescue LoadError
        str = "#{str1.ljust(@@col_wid[idx])}  Does not load!".ljust(@@col_wid[0])
      end
      begin
        require req2
        puts str + "#{str2.ljust(@@col_wid[idx+1])}  Ok"
      rescue LoadError
        puts str + "#{str2.ljust(@@col_wid[idx+1])}  Does not load!"
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
      ret = sio_out.string
      cmd.ui = orig_ui
      ary_bundled = ret.split(/\r*\n/)
      puts "\n#{@@dash * 12} #{"Default Gems #{@@dash * 5}".ljust(30)} #{@@dash * 12} Bundled Gems #{@@dash * 4}"
      ary_bundled.reject! { |i| /^[a-z]/ !~ i }
      ary_default = ary_bundled.select { |i| /\(default:/ =~ i }
      ary_bundled.reject! { |i| /\(default:/ =~ i }

      ary_default.map! { |i| i.gsub(/\(default: |\)/, '') }
      ary_bundled.map! { |i| i.gsub(/[()]/, '') }

      max_rows = [ary_default.length || 0, ary_bundled.length || 0].max
      (0..(max_rows-1)).each { |i|
        dflt  = ary_default[i] ? ary_default[i].split(" ") : ["", ""]
        bndl  = ary_bundled[i] ? ary_bundled[i].split(" ") : nil
        if bndl
          puts "#{dflt[1].rjust(12)} #{dflt[0].ljust(30)} #{bndl[1].rjust(12)} #{bndl[0]}"
        else
          puts "#{dflt[1].rjust(12)} #{dflt[0]}"
        end
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
      if OpenSSL::VERSION <= '2.0.9'
        additional('SSLContext::METHODS', 0, 4) {
          ssl::SSLContext::METHODS.reject { |e| /client|server/ =~ e }.sort.join(' ')
        }
      else
        additional('SSLContext versions', 0, 4) {
          ctx = OpenSSL::SSL::SSLContext.new
          if  ctx.respond_to? :min_version=
            ssl_methods = []
            all_ssl_meths =
            [ [ssl::SSL2_VERSION  , 'SSLv2'  ],
              [ssl::SSL3_VERSION  , 'SSLv3'  ],
              [ssl::TLS1_VERSION  , 'TLSv1'  ],
              [ssl::TLS1_1_VERSION, 'TLSv1_1'],
              [ssl::TLS1_2_VERSION, 'TLSv1_2']
            ]
            if defined? ssl::TLS1_3_VERSION
              all_ssl_meths << [ssl::TLS1_3_VERSION, 'TLSv1_3']
            end
            all_ssl_meths.each { |m|
              begin
                ctx.min_version = m[0]
                ctx.max_version = m[0]
                ssl_methods << m[1]
              rescue
              end
            }
            ssl_methods.join(' ')
          else
            ''
          end
        }
      end
    end

    def ssl_verify
      require 'net/http'
      #uri = URI.parse('https://sourceware.org/pub/libffi/')
      uri = URI.parse('https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess')
      Net::HTTP.start(uri.host, uri.port, :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_PEER) { |https|
        req = Net::HTTP::Get.new uri
      }
      "Success"
    rescue OpenSSL::SSL::SSLError => e
      "*** FAILURE ***"
    end

  end
end

VersInfo.run ; exit 0
