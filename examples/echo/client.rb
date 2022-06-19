#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require 'async'
require 'async/io/trap'
require 'async/io/host_endpoint'
require 'async/io/stream'
require 'async/io/ssl_endpoint'

custom_context = OpenSSL::SSL::SSLContext.new.tap do |context|
  context.ca_file = File.expand_path('ca_cert.pem', __dir__)
  context.verify_mode = OpenSSL::SSL::VERIFY_PEER
end

custom_multiple_context = OpenSSL::SSL::SSLContext.new.tap do |context|
  context.cert_store = OpenSSL::X509::Store.new.tap do |store|
    store.add_file(File.expand_path('ca_cert.pem', __dir__))
  end
  context.verify_mode = OpenSSL::SSL::VERIFY_PEER
  # context.verify_hostname = true
  # context.min_version = OpenSSL::SSL::TLS1_2_VERSION
end

system_context = OpenSSL::SSL::SSLContext.new.tap do |context|
  context.verify_mode = OpenSSL::SSL::VERIFY_PEER
end

all_context = OpenSSL::SSL::SSLContext.new.tap do |context|
  context.verify_mode = OpenSSL::SSL::VERIFY_NONE
end

endpoint = Async::IO::Endpoint.tcp('localhost', 4578)
endpoint = Async::IO::SSLEndpoint.new(endpoint, ssl_context: custom_multiple_context, hostname: 'localhost')

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
