Gem::Specification.new do |s|
  s.name = 'miab'
  s.version = '0.3.0'
  s.summary = 'Message in a bottle (MIAB) is designed to execute remote ' +
      'commands through SSH for system maintenance purposes.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/miab.rb']
  s.add_runtime_dependency('net-ssh', '~> 5.2', '>=5.2.0')
  s.add_runtime_dependency('c32', '~> 0.2', '>=0.2.0')
  s.signing_key = '../privatekeys/miab.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/miab'
end
