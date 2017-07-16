require "rbconfig"

module VersInfo
  @@col_wid = [28,15,15]
  
  class << self
  
    def run
      puts " #{Time.now.getutc}     Appveyor Ruby #{RUBY_VERSION}".rjust(110, '-')
      puts RUBY_DESCRIPTION
      puts
      gcc = RbConfig::CONFIG["CC_VERSION_MESSAGE"] ?
        RbConfig::CONFIG["CC_VERSION_MESSAGE"][/\A.+?\n/] : 'unknown'
      puts "gcc info: #{gcc}\n"
      first('gdbm'    , 'GDBM::VERSION'   , 15)  { GDBM::VERSION    }
      first('rubygems', 'Gem::VERSION'    , 15)  { Gem::VERSION     }
      first('json'    , 'JSON::VERSION'   , 15)  { JSON::VERSION    }
      puts
      if first('openssl', 'OpenSSL::VERSION', 0)    { OpenSSL::VERSION }
        additional('OPENSSL_VERSION'        , 0, 4) { OpenSSL::OPENSSL_VERSION }
        if OpenSSL.const_defined?(:OPENSSL_LIBRARY_VERSION)
          additional('OPENSSL_LIBRARY_VERSION', 0, 4) { OpenSSL::OPENSSL_LIBRARY_VERSION }
        end
        additional('DEFAULT_CONFIG_FILE    ', 0, 4) { OpenSSL::Config::DEFAULT_CONFIG_FILE }
      end
      puts

      double('psych', 'Psych::VERSION', 'LIBYAML_VERSION', 0) { [Psych::VERSION, Psych::LIBYAML_VERSION] }
      unless first('readline', 'Readline::VERSION (ext)', 0) { Readline::VERSION }
        first('rb-readline', 'Readline::VERSION (gem)'  , 0) { Readline::VERSION }
      end
      first('zlib'    , 'Zlib::ZLIB_VERSION', 0)  { Zlib::ZLIB_VERSION }
      puts
      loads?('socket', 'Socket')
      loads?('win32/registry', 'Win32::Registry')
      loads?('win32ole', 'WIN32OLE')
      
      gem_list
      
      puts "\n#{'-' * 45} ENV Info"
      puts "OPENSSL_CONF  #{ENV['OPENSSL_CONF']}"
      puts "SSL_CERT_FILE #{ENV['SSL_CERT_FILE']}"
      puts "\n#{'-' * 110}"
    end

  private
    
    def loads?(req, str)
      begin
        require req
        puts "#{str.ljust(@@col_wid[0])}  Ok"
      rescue
        puts "#{str.ljust(@@col_wid[0])}  Does not load!"
      end
    end
  
    def first(req, text, idx)
      col = idx > 10 ? idx : @@col_wid[idx]
      require req
      puts "#{text.ljust(col)}  #{yield}"
      true
    rescue LoadError
      puts "#{text.ljust(col)}  NOT FOUND!"
      false
    end
    
    def additional(text, idx, indent = 0)
      puts "#{(' ' * indent + text).ljust(@@col_wid[idx])}  #{yield}"
    rescue LoadError
    end
    
    def double(req, text1, text2, idx)
      require req
      val1, val2 = yield
      puts "#{text1.ljust(@@col_wid[idx]  )}  #{val1.ljust(@@col_wid[idx+1])}" \
           "#{text2.ljust(@@col_wid[idx+2])}  #{val2}"
    rescue LoadError
      puts "#{text1.ljust(@@col_wid[idx])}  NOT FOUND!"
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
