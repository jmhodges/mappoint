# -*- ruby -*-

require 'hoe'

LIB_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH << LIB_DIR

require 'mappoint'

Hoe.plugin :git

Hoe.spec('mappoint') do
  # p.rubyforge_name = 'mappoint' # if different than lowercase project name
  developer('Jeff Hodges', 'jeff@somethingsimilar.com')
  extra_deps << ['handsoap', '~> 0.5.3']
end

# vim: syntax=Ruby
