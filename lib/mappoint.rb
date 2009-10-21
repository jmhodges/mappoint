require 'handsoap'
require 'digest/md5'
require 'uri'
require 'cgi'

require 'mappoint/digest_auth'
require 'mappoint/service'

require 'mappoint/common'
require 'mappoint/render'
require 'mappoint/route'
require 'mappoint/find'

module MapPoint
  VERSION = '0.2.0'
  class << self
    attr_accessor :username, :password
  end
end
