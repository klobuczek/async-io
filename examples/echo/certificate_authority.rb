require 'async/io/ssl_endpoint'

class CertificateAuthority < OpenSSL::X509::Certificate
  attr :certificate_authority_key

  def initialize(certificate_authority_key, certificate_authority_name)
    super()
    @certificate_authority_key = certificate_authority_key
    self.subject = certificate_authority_name
    self.issuer = certificate_authority_name
    self.public_key = certificate_authority_key.public_key
    self.serial = 1
    self.version = 2
    self.not_before = Time.now
    self.not_after = Time.now + 3600
    extension_factory = OpenSSL::X509::ExtensionFactory.new
    extension_factory.subject_certificate = self
    extension_factory.issuer_certificate = self
    add_extension extension_factory.create_extension("basicConstraints", "CA:TRUE", true)
    add_extension extension_factory.create_extension("keyUsage", "keyCertSign, cRLSign", true)
    add_extension extension_factory.create_extension("subjectKeyIdentifier", "hash")
    add_extension extension_factory.create_extension("authorityKeyIdentifier", "keyid:always", false)
    sign(certificate_authority_key, OpenSSL::Digest::SHA256.new)
  end
  DEFAULT = CertificateAuthority.new(OpenSSL::PKey::RSA.new(2048), OpenSSL::X509::Name.parse('O=TestCA/CN=localhost'))

  def certificate_store
    OpenSSL::X509::Store.new.tap do |certificates|
      certificates.add_cert(self)
    end
  end
end
