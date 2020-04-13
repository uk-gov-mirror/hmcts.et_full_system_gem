
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "et_full_system/version"

Gem::Specification.new do |spec|
  spec.name          = "et_full_system"
  spec.version       = EtFullSystem::VERSION
  spec.authors       = ["Gary Taylor"]
  spec.email         = ["gary.taylor@hmcts.net"]

  spec.summary       = %q{Runs the employment tribunals system - all services and background jobs}
  spec.description   = %q{Runs the employment tribunals system - all services and background jobs}
  spec.homepage      = "https://github.com/ministryofjustice/et-full-system"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency 'thor', '~> 1.0'
  spec.add_dependency 'httparty', '~> 0.16'
  spec.add_dependency 'aws-sdk-s3', '~> 1.9'
  spec.add_dependency 'azure-storage', '~> 0.15.0.preview'
  spec.add_dependency 'dotenv', '~> 2.7', '>= 2.7.2'
  spec.add_dependency 'et_fake_acas_server', '~> 0.1'
  spec.add_dependency 'et_fake_ccd', '~> 1.0'

  spec.add_development_dependency "rake", "~> 13.0"
end
