# -*- ruby -*-
GEMSPEC = Gem::Specification.new do |spec|

  # Project information
  spec.name        = "openrubyrmk-backend"
  spec.summary     = "The OpenRubyRMK's backend library"
  spec.description =<<-DESCRIPTION
This is the backend library of the OpenRubyRMK, the free
and open-source RPG creation program written in Ruby. It
does the heavy work of what is exposed through GUI frontends.
  DESCRIPTION
  spec.version     = File.read("VERSION").strip.gsub("-", ".")
  spec.author      = "The OpenRubyRMK team"
  spec.email       = "openrubyrmk@googlemail.com"

  # Requirements
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 1.9.2"
  spec.add_dependency("ruby-tmx")
  spec.add_dependency("nokogiri")
  spec.add_development_dependency("turn")
  spec.add_development_dependency("paint")

  # Gem contents
  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  spec.has_rdoc         = true
  spec.extra_rdoc_files = ["README.rdoc", "COPYING"]
  spec.rdoc_options << "-t" << "The Backend's RDocs" << "-m" << "README.rdoc"

end
