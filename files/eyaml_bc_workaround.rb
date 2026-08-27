#!/opt/puppetlabs/puppet/bin/ruby
# BouncyCastle >= 1.85 (PE 2025.11.2) refuses to parse certificates with an
# empty issuer DN, which is what `eyaml createkeys` produces, so puppetserver
# cannot decrypt any ENC[PKCS7,...] value. PKCS7#decrypt does not need the
# certificate, so drop it. Remove once Puppet ships a fixed hiera-eyaml.

GLOB = '/opt/puppetlabs/puppet/lib/ruby/vendor_gems/gems/hiera-eyaml-*/lib/hiera/backend/eyaml/encryptors/pkcs7.rb'.freeze

file = Dir.glob(GLOB).first
abort "no hiera-eyaml pkcs7.rb under #{GLOB}" if file.nil?

source = File.read(file)
if source.include?('pkcs7.decrypt(private_key_rsa)')
  puts "already patched: #{file}"
  exit 0
end

# Anchor on def self.decrypt so the identical line in self.encrypt is left alone
patched = source.sub(
  /(def self\.decrypt\b.*?)^([ \t]*)public_key_x509 = OpenSSL::X509::Certificate\.new\( public_key_pem \)\n/m
) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}# patched: BC >= 1.85 rejects empty-issuer-DN certs\n" }
abort "cert load line not found in self.decrypt: #{file}" if patched == source

replaced = patched.sub('pkcs7.decrypt(private_key_rsa, public_key_x509)', 'pkcs7.decrypt(private_key_rsa)')
abort "decrypt call not found: #{file}" if replaced == patched

File.write(file, replaced)
puts "patched #{file}"

# JRuby caches the loaded class, so the running puppetserver keeps the old code
if system('/bin/systemctl', 'is-active', '--quiet', 'pe-puppetserver')
  abort 'pe-puppetserver restart failed' unless system('/bin/systemctl', 'restart', 'pe-puppetserver')
  puts 'restarted pe-puppetserver'
end
