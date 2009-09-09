require 'handsoap'
require 'digest/md5'
require 'uri'
require 'cgi'

require 'mappoint/digest_auth'
require 'mappoint/service'

require 'mappoint/common'
require 'mappoint/render'
require 'mappoint/route'

module MapPoint
  VERSION = '0.1.0'
  class << self
    attr_accessor :username, :password
  end
end
