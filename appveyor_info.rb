require "rbconfig"

module VersInfo
  @@col_wid = [34, 14, 17, 26, 10, 16]
  
  class << self
  
    def run
      puts " #{Time.now.getutc}     Appveyor Ruby #{RUBY_VERSION}".rjust(110, '-')
      puts RUBY_DESCRIPTION
      puts
      gcc = RbConfig::CONFIG["CC_VERSION_MESSAGE"] ?
        RbConfig::CONFIG["CC_VERSION_MESSAGE"][/\A.+?\n/] : 'unknown'
      puts "gcc info: #{gcc}\n"
      first('rubygems'  , 'Gem::VERSION'  , 18)  { Gem::VERSION     }
      puts
      first('bigdecimal', 'BigDecimal.ver', 18)  { BigDecimal.ver   }
      first('gdbm'      , 'GDBM::VERSION' , 18)  { GDBM::VERSION    }
      first('json'      , 'JSON::VERSION' , 18)  { JSON::VERSION    }
      puts
      if first('openssl', 'OpenSSL::VERSION', 0) { OpenSSL::VERSION }
        additional('OPENSSL_VERSION'        , 0, 4) { OpenSSL::OPENSSL_VERSION }
        if OpenSSL.const_defined?(:OPENSSL_LIBRARY_VERSION)
          additional('OPENSSL_LIBRARY_VERSION', 0, 4) { OpenSSL::OPENSSL_LIBRARY_VERSION }
        else
          additional('OPENSSL_LIBRARY_VERSION', 0, 4) { "Not Defined" }
        end
        additional('SSLContext::METHODS', 0, 4) {
          OpenSSL::SSL::SSLContext::METHODS.reject { |e| /client|server/ =~ e }.sort.join(' ')
        }
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
      unless first('readline', 'Readline::VERSION (ext)', 3) { Readline::VERSION }
        first('rb-readline', 'Readline::VERSION (gem)'  , 3) { Readline::VERSION }
      end
      double('zlib', 'Zlib::VERSION', 'ZLIB_VERSION', 3, 1, 2) { [Zlib::VERSION, Zlib::ZLIB_VERSION] }
      puts
      puts "\n#{'-' * 56} Load Test"
      loads2?('dbm'   , 'DBM'   , 'win32/registry', 'Win32::Registry', 4)
      loads2?('digest', 'Digest', 'win32ole'      , 'WIN32OLE'       , 4)
      loads2?('fiddle', 'Fiddle', 'zlib'          , 'Zlib'           , 4)
      loads1?('socket', 'Socket', 4)
      
      gem_list

      puts "\n#{'-' * 110}"
    end

  private
    
    def loads1?(req, str, idx)
      begin
        require req
        puts "#{str.ljust(@@col_wid[idx])}  Ok"
      rescue LoadError
        puts "#{str.ljust(@@col_wid[idx])}  Does not load!"
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
        found = File.exist?(fn) ? File.mtime(fn).utc.strftime('File Dated %F') : 'File Not Found!      '
      else
        found = Dir.exist?(fn) ? 'Dir  Exists          ' : 'Dir  Not Found!      '
      end
      puts "#{(' ' * indent + text).ljust(@@col_wid[idx])}#{found}  #{fn}"
    rescue LoadError
    end

    def env_file_exists(env)
      if fn = ENV[env]
        if /\./ =~ File.basename(fn)
          "#{ File.exist?(fn) ? "#{File.mtime(fn).utc.strftime('File Dated %F')}" : 'File Not Found!      '}  #{fn}"
        else
          "#{ Dir.exist?(fn) ? 'Dir  Exists          ' : 'Dir  Not Found!      '}  #{fn}"
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
      puts "\n#{"-" * 12} #{'Default Gems ----'.ljust(30)} #{"-" * 12} Bundled Gems ----"
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
  end
end

VersInfo.run ; exit 0
