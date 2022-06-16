require 'async/io/ssl_endpoint'

class Certificate < OpenSSL::X509::Certificate
  attr :key

  def initialize(o_name, serial: 1, authority: self)
    key = OpenSSL::PKey::RSA.new(2048)
    name = OpenSSL::X509::Name.parse("O=#{o_name}/CN=localhost")
    super()
    @key = key
    self.subject = name
    self.issuer = authority.subject
    self.public_key = key.public_key
    self.serial = serial
    self.version = 2
    self.not_before = Time.now
    self.not_after = Time.now + 3600
    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = self
    extension_factory.issuer_certificate = authority
    add_extension extension_factory.create_extension("subjectKeyIdentifier", "hash")
    if authority == self
      add_extension extension_factory.create_extension("basicConstraints", "CA:TRUE", true)
      add_extension extension_factory.create_extension("keyUsage", "keyCertSign, cRLSign", true)
      add_extension extension_factory.create_extension("authorityKeyIdentifier", "keyid:always", false)
    else
      add_extension extension_factory.create_extension("keyUsage", "digitalSignature", true)
    end
    sign(authority.key, OpenSSL::Digest::SHA256.new)
  end

  def store
    OpenSSL::X509::Store.new.tap do |certificates|
      certificates.add_cert(self)
    end
  end
end
