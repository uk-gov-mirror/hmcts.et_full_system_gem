require "et_full_system/version"
require 'socket'

module EtFullSystem

  def self.is_port_open?(port, ip: '0.0.0.0')
    s = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
    sa = Socket.sockaddr_in(port, ip)

    begin
      s.connect_nonblock(sa)
    rescue Errno::EINPROGRESS
      if IO.select(nil, [s], nil, 1)
        begin
          s.connect_nonblock(sa)
        rescue Errno::EISCONN
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          return false
        end
      end
    end

    return false
  end
end
