require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
])
SimpleCov.start do
  add_filter '/spec/'
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  #  config.order = 'random'

  config.before(:each) do
    clear_db
  end

  config.after :suite do
    RailsSettingsMigration.migrate(:down)
  end
end

require 'active_record'
require 'protected_attributes' if ENV['PROTECTED_ATTRIBUTES'] == 'true'
require 'rails-settings'

if I18n.respond_to?(:enforce_available_locales=)
  I18n.enforce_available_locales = false
end

class User < ActiveRecord::Base
  has_settings do |s|
    s.key :dashboard, :defaults => { :theme => 'blue', :view => 'monthly', :filter => true, owner_name: -> (target) { target.name } }
    s.key :calendar,  :defaults => { :scope => 'company', :events => [], :profile => {} }
  end
end

class GuestUser < User
  has_settings do |s|
    s.key :dashboard, :defaults => { :theme => 'red', :view => 'monthly', :filter => true }
  end
end

class Account < ActiveRecord::Base
  has_settings :portal
end

class Project < ActiveRecord::Base
  has_settings :info, :class_name => 'ProjectSettingObject'
end

class ProjectSettingObject < RailsSettings::SettingObject
  validate do
    unless self.owner_name.present? && self.owner_name.is_a?(String)
      errors.add(:base, "Owner name is missing")
    end
  end
end

def setup_db
  ActiveRecord::Base.configurations = YAML.load_file(File.dirname(__FILE__) + '/database.yml')
  ActiveRecord::Base.establish_connection(:sqlite)
  ActiveRecord::Migration.verbose = false

  print "Testing with ActiveRecord #{ActiveRecord::VERSION::STRING}"
  if ActiveRecord::VERSION::MAJOR == 4
    print " #{defined?(ProtectedAttributes) ? 'with' : 'without'} gem `protected_attributes`"
  end
  puts

  require File.expand_path('../../lib/generators/rails_settings/migration/templates/migration.rb', __FILE__)
  RailsSettingsMigration.migrate(:up)

  ActiveRecord::Schema.define(:version => 1) do
    create_table :users do |t|
      t.string :type
      t.string :name
    end

    create_table :accounts do |t|
      t.string :subdomain
    end

    create_table :projects do |t|
      t.string :name
    end
  end
end

def clear_db
  User.delete_all
  Account.delete_all
  RailsSettings::SettingObject.delete_all
end

setup_db
