# frozen_string_literal: true
=begin
ruby C:\Greg\GitHub\appveyor_ruby\ssl_test.rb
=end

#require_relative "utils"

require 'openssl'
require 'socket'

module TestSSL

  HAS_MIN_MAX = (OpenSSL::VERSION >= '2.1')
  
  class << self

    def check_supported_protocol_versions
      setup
      if HAS_MIN_MAX
        ssl = OpenSSL::SSL
        possible_versions = []

        ssl.const_defined?(:SSL3_VERSION)   &&
          possible_versions << [ssl::SSL3_VERSION  , 'SSLv3'  ]
        ssl.const_defined?(:TLS1_VERSION)   && 
          possible_versions << [ssl::TLS1_VERSION  , 'TLSv1'  ]
        ssl.const_defined?(:TLS1_1_VERSION) &&
          possible_versions << [ssl::TLS1_1_VERSION, 'TLSv1_1']
        ssl.const_defined?(:TLS1_2_VERSION) &&
          possible_versions << [ssl::TLS1_2_VERSION, 'TLSv1_2']
        ssl.const_defined?(:TLS1_3_VERSION) &&
          possible_versions << [ssl::TLS1_3_VERSION, 'TLSv1_3']
      else
        possible_versions = [
          [:SSLv2_server  , 'SSLv2'  ],
          [:SSLv3_server  , 'SSLv3'  ],
          [:TLSv1_server  , 'TLSv1'  ],
          [:TLSv1_1_server, 'TLSv1_1'],
          [:TLSv1_2_server, 'TLSv1_2']
        ]
      end
      # Prepare for testing & do sanity check
      supported = []
      possible_versions.each do |ary|
        ver, desc = ary
        catch(:unsupported) {
          ctx_proc = proc { |ctx|
            begin
              if HAS_MIN_MAX
                ctx.min_version = ctx.max_version = ver
              else
                ctx.ssl_version = ver
              end
            rescue ArgumentError, OpenSSL::SSL::SSLError
              throw :unsupported
            end
          }
          start_server(ctx_proc: ctx_proc, ignore_listener_error: true) do |port|
            begin
              server_connect(port) { |ssl|
                ssl.puts "abc"; ssl.gets
              }
            rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET => e
              # puts e.message
            else
              supported << desc
            end
          end
        }
      end
      supported.join ' '
    end

    private

    def setup
      @ca_key  = pkey("rsa2048")
      @svr_key = pkey("rsa1024")
      ca      = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=CA")
      svr     = OpenSSL::X509::Name.parse("/DC=org/DC=ruby-lang/CN=localhost")

      ca_exts = [
        ["basicConstraints","CA:TRUE",true],
        ["keyUsage","cRLSign,keyCertSign",true],
      ]
      ee_exts = [
        ["keyUsage","keyEncipherment,digitalSignature",true],
      ]

      @ca_cert  = issue_cert(ca , @ca_key , 1, ca_exts, nil     , nil   )
      @svr_cert = issue_cert(svr, @svr_key, 2, ee_exts, @ca_cert, @ca_key)
    end
   
    def readwrite_loop(ctx, ssl)
      while line = ssl.gets
        ssl.write(line)
      end
    end

    def start_server(verify_mode: OpenSSL::SSL::VERIFY_NONE, start_immediately: true,
                     ctx_proc: nil, server_proc: method(:readwrite_loop),
                     ignore_listener_error: false, &block)
      IO.pipe {|stop_pipe_r, stop_pipe_w|
        store = OpenSSL::X509::Store.new
        store.add_cert(@ca_cert)
        store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.cert_store = store
        ctx.cert = @svr_cert
        ctx.key  = @svr_key
        ctx.tmp_dh_callback = proc { pkey_dh("dh1024") }
        ctx.verify_mode = verify_mode
        ctx_proc.call(ctx) if ctx_proc

        Socket.do_not_reverse_lookup = true
        tcps = TCPServer.new("127.0.0.1", 0)
        port = tcps.connect_address.ip_port

        ssls = OpenSSL::SSL::SSLServer.new(tcps, ctx)
        ssls.start_immediately = start_immediately

        threads = []
        begin
          server_thread = Thread.new do
            if Thread.method_defined?(:report_on_exception=) # Ruby >= 2.4
              Thread.current.report_on_exception = false
            end

            begin
              loop do
                begin
                  readable, = IO.select([ssls, stop_pipe_r])
                  break if readable.include? stop_pipe_r
                  ssl = ssls.accept
                rescue OpenSSL::SSL::SSLError, IOError, Errno::EBADF, Errno::EINVAL,
                       Errno::ECONNABORTED, Errno::ENOTSOCK, Errno::ECONNRESET
                  retry if ignore_listener_error
                  raise
                end

                th = Thread.new do
                  if Thread.method_defined?(:report_on_exception=)
                    Thread.current.report_on_exception = false
                  end

                  begin
                    server_proc.call(ctx, ssl)
                  ensure
                    ssl.close
                  end
                  true
                end
                threads << th
              end
            ensure
              tcps.close
            end
          end

          client_thread = Thread.new do
            if Thread.method_defined?(:report_on_exception=)
              Thread.current.report_on_exception = false
            end

            begin
              block.call(port)
            ensure
              # Stop accepting new connection
              stop_pipe_w.close
              server_thread.join
            end
          end
          threads.unshift client_thread
        ensure
          # Terminate existing connections. If a thread did 'pend', re-raise it.
          pend = nil
          threads.each { |th|
            begin
              th.join(10) or
                th.raise(RuntimeError, "[start_server] thread did not exit in 10 secs")
#            rescue (defined?(MiniTest::Skip) ? MiniTest::Skip : Test::Unit::PendedError)
#              # MiniTest::Skip is for the Ruby tree
#              pend = $!
            rescue Exception => e
              puts "threads #{e.message}"
            end
          }
#          raise pend if pend

          errs = []
          values = []
          while th = threads.shift
            begin
              values << th.value
            rescue Exception
              errs << [th, $!]
            end
          end          
          values
        end
      }
    end

    def server_connect(port, ctx = nil)
      sock = TCPSocket.new("127.0.0.1", port)
      ssl = ctx ? OpenSSL::SSL::SSLSocket.new(sock, ctx) : OpenSSL::SSL::SSLSocket.new(sock)
      ssl.sync_close = true
      ssl.connect
      yield ssl if block_given?
    ensure
      if ssl
        ssl.close
      elsif sock
        sock.close
      end
    end

    def issue_cert(dn, key, serial, extensions, issuer, issuer_key,
                   not_before: nil, not_after: nil, digest: "sha256")
      cert = OpenSSL::X509::Certificate.new
      issuer = cert unless issuer
      issuer_key = key unless issuer_key
      cert.version = 2
      cert.serial = serial
      cert.subject = dn
      cert.issuer = issuer.subject
      cert.public_key = key
      now = Time.now
      cert.not_before = not_before || now - 3600
      cert.not_after = not_after || now + 3600
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = issuer
      extensions.each{|oid, value, critical|
        cert.add_extension(ef.create_extension(oid, value, critical))
      }
      cert.sign(issuer_key, digest)
      cert
    end

    def pkey(name)
      OpenSSL::PKey.read(read_file(name))
    end

    def pkey_dh(name)
      # DH parameters can be read by OpenSSL::PKey.read atm
      OpenSSL::PKey::DH.new(read_file(name))
    end

    def read_file(name)
        File.read(File.join(__dir__, "pkey", name + ".pem"))
    end

  end
 
end
