#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
$LOAD_PATH.unshift File.expand_path(__dir__)

require 'async'
require 'async/io/trap'
require 'async/io/host_endpoint'
require 'async/io/stream'
require 'certificate_authority'

client_context = OpenSSL::SSL::SSLContext.new.tap do |context|
  context.cert_store = CertificateAuthority::DEFAULT.certificate_store
  context.verify_mode = OpenSSL::SSL::VERIFY_PEER
end

endpoint = Async::IO::Endpoint.tcp('localhost', 4578)
endpoint = Async::IO::SSLEndpoint.new(endpoint, ssl_context: client_context)

Async do |task|
	endpoint.connect do |peer|
		stream = Async::IO::Stream.new(peer)
		
		while true
			task.sleep 1
			stream.puts "Hello World!"
			puts stream.gets.inspect
		end
	end
end
