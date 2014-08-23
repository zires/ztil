# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require "ztil"

Gem::Specification.new do |s|
  s.name        = "ztil"
  s.version     = Ztil::VERSION
  s.authors     = ["zires"]
  s.email       = ["zshuaibin@gmail.com"]
  s.homepage    = "https://github.com/zires/ztil"
  s.summary     = "The utils of zires"
  s.description = "The utils of zires...include Backup database to qi_niu"
  s.license     = 'MIT'

  s.files = Dir["{lib}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]
  s.require_path  = 'lib'
  s.executables   = ['ztil']

  s.add_dependency "thor", '= 0.19.1'
  s.add_dependency "rest-client", '= 1.7.2'
  s.add_dependency "backup_zh", '= 4.0.3.1'
  s.add_dependency "whenever", "= 0.9.2"

end
