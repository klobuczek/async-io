#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'async/io/trap'
require 'async/io/host_endpoint'
require 'async/io/stream'
require 'async/io/ssl_endpoint'

server_context =
  OpenSSL::SSL::SSLContext.new.tap do |context|
    context.key = OpenSSL::PKey::RSA.new(File.read(File.expand_path('key.pem', __dir__)))
    context.cert = OpenSSL::X509::Certificate.new(File.read(File.expand_path('cert.pem', __dir__)))
  end

endpoint = Async::IO::Endpoint.tcp('localhost', 4578)
endpoint = Async::IO::SSLEndpoint.new(endpoint, ssl_context: server_context)

interrupt = Async::IO::Trap.new(:INT)

Async do |top|
	interrupt.install!
	
	endpoint.bind do |server, task = Async::Task.current|
		Console.logger.info(server) {"Accepting connections on #{server.local_address.inspect}"}
		
    task.async do |subtask|
			interrupt.wait
			
			Console.logger.info(server) {"Closing server socket..."}
			server.close
			
			interrupt.default!
			
			Console.logger.info(server) {"Waiting for connections to close..."}
			subtask.sleep(4)
			
			Console.logger.info(server) do |buffer|
				buffer.puts "Stopping all tasks..."
				task.print_hierarchy(buffer)
				buffer.puts "", "Reactor Hierarchy"
				task.reactor.print_hierarchy(buffer)
			end
			
			task.stop
		end
		
		server.listen(128)
		
		server.accept_each do |peer|
			stream = Async::IO::Stream.new(peer)
			
			while chunk = stream.read_partial
				Console.logger.debug(self) {chunk.inspect}
				stream.write(chunk)
				stream.flush
				
				Console.logger.info(server) do |buffer|
					task.reactor.print_hierarchy(buffer)
				end
			end
		end
	end
end
