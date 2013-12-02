require "rake/clean"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require_relative "spec/env"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "-t ~org"
end

CLEAN << VENDOR_ORG_MODE_DIR <<
  "vendor/org-#{ORG_VERSION}" <<
  "vendor/org-#{ORG_VERSION}.tar.gz"

task :default        => :spec
task :spec           => :vendor_orgmode
task :vendor_orgmode => VENDOR_ORG_MODE_DIR

file VENDOR_ORG_MODE_DIR => "vendor/org-#{ORG_VERSION}" do |t|
  mkdir_p File.expand_path("..", VENDOR_ORG_MODE_DIR)
  ln_sf File.expand_path("vendor/org-#{ORG_VERSION}"), VENDOR_ORG_MODE_DIR
end

directory "vendor/org-#{ORG_VERSION}" => "vendor/org-#{ORG_VERSION}.tar.gz" do |t|
  cd "vendor" do
    sh "tar -xzf org-#{ORG_VERSION}.tar.gz"
  end
  cd "vendor/org-#{ORG_VERSION}" do
    sh "make"
  end
end

file "vendor/org-#{ORG_VERSION}.tar.gz" => "vendor/org" do |t|
  cd "vendor" do
    sh "wget http://orgmode.org/org-#{ORG_VERSION}.tar.gz"
  end
end

directory "vendor/org"
