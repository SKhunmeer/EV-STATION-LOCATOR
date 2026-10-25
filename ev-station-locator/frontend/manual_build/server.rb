require 'socket'
require 'cgi'

root = File.expand_path(__dir__)
server = TCPServer.new('127.0.0.1', 8080)
mime = {
  '.html' => 'text/html; charset=utf-8',
  '.js' => 'application/javascript; charset=utf-8',
  '.json' => 'application/json; charset=utf-8',
  '.png' => 'image/png',
  '.wasm' => 'application/wasm',
  '.css' => 'text/css; charset=utf-8',
}

loop do
  socket = server.accept
  request = socket.gets
  path = request.to_s.split[1].to_s.split('?').first
  path = '/index.html' if path.empty? || path == '/'
  relative = CGI.unescape(path).sub(%r{^/}, '')
  file = File.expand_path(relative, root)
  if !file.start_with?(root + File::SEPARATOR) || !File.file?(file)
    body = "Not found\n"
    socket.write("HTTP/1.1 404 Not Found\r\nContent-Length: #{body.bytesize}\r\n\r\n#{body}")
  else
    body = File.binread(file)
    type = mime[File.extname(file)] || 'application/octet-stream'
    socket.write("HTTP/1.1 200 OK\r\nContent-Type: #{type}\r\nContent-Length: #{body.bytesize}\r\nCache-Control: no-cache\r\n\r\n")
    socket.write(body)
  end
  socket.close
end
