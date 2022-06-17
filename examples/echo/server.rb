#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
$LOAD_PATH.unshift File.expand_path(__dir__)

require 'async'
require 'async/io/trap'
require 'async/io/host_endpoint'
require 'async/io/stream'
require 'certificate_authority'

key = OpenSSL::PKey::RSA.new(2048)
certificate_name = OpenSSL::X509::Name.parse("O=Test/CN=localhost")

valid_certificate = begin
	certificate = OpenSSL::X509::Certificate.new
	certificate.subject = certificate_name
	certificate.issuer = CertificateAuthority::DEFAULT.subject
	certificate.public_key = key.public_key
	certificate.serial = 2
	certificate.version = 2
	certificate.not_before = Time.now
	certificate.not_after = Time.now + 3600
	extension_factory = OpenSSL::X509::ExtensionFactory.new()
	extension_factory.subject_certificate = certificate
	extension_factory.issuer_certificate = CertificateAuthority::DEFAULT
	certificate.add_extension extension_factory.create_extension("keyUsage", "digitalSignature", true)
	certificate.add_extension extension_factory.create_extension("subjectKeyIdentifier", "hash")
	certificate.sign CertificateAuthority::DEFAULT.certificate_authority_key, OpenSSL::Digest::SHA256.new
end

server_context =
  OpenSSL::SSL::SSLContext.new.tap do |context|
    context.key = OpenSSL::PKey::RSA.new File.read 'key.pem'
    context.cert = OpenSSL::X509::Certificate.new File.read 'cert.pem'
  end

endpoint = Async::IO::Endpoint.tcp('localhost', 4578)
endpoint = Async::IO::SSLEndpoint.new(endpoint, ssl_context: server_context)

interrupt = Async::IO::Trap.new(:INT)

Async do |top|
	interrupt.install!
	
	endpoint.bind do |server, task|
		Console.logger.info(server) {"Accepting connections on #{server.local_address.inspect}"}
		
    	Async do |subtask|
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
