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

endpoint = Async::IO::Endpoint.tcp('staging.orglabsolutions.com', 7687)
endpoint = Async::IO::SSLEndpoint.new(endpoint, ssl_context: all_context, hostname: 'localhost')

def bolt_version(version)
  pad(version.split(/[.\-]/).map(&:to_i), 4).reverse
end

def ruby_version(bolt_version)
  bolt_version.unpack('C*').reverse.map(&:to_s).join('.')
end

def bolt_versions(*versions)
  pad(versions[0..3].map(&method(:bolt_version)).flatten, 16).pack('C*')
end

def pad(arr, n)
  arr + [0] * [0, n - arr.size].max
end

peer = nil
stream = nil
Async do |task|
  peer = endpoint.connect
end
stream = Async::IO::Stream.new(peer)

# Async do |task|
GOGOBOLT = ["6060B017"].pack('H*')
stream.write(GOGOBOLT)
# end

puts peer
puts stream
# puts Async::Task.current

# Async do |task|
stream.write(bolt_versions('3.5', '4.1'))
# end

# Async do |task|
puts ruby_version(stream.read(4))
# end

# Async do |task|
peer.close
# end
