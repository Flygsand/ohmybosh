require 'rake/gempackagetask'

begin
  require 'spec/rake/spectask'
  desc 'Run specs'
  Spec::Rake::SpecTask.new('spec') do |t|
    t.spec_files = FileList['spec/**/*_spec.rb']
  end
rescue LoadError; end

spec = Gem::Specification.new do |gem|
  gem.name = 'ohmybosh'
  gem.version = '0.0.1'
  gem.summary = 'Ruby XMPP BOSH session initializer'
  gem.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new(spec) do |pkg|
end
