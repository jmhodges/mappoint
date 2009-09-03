module MapPoint
##
#  HTTP Digest Authentication

module DigestAuth
  @@nonce_count = Hash.new(0)
  CNONCE = Digest::MD5.hexdigest("%x" % (Time.now.to_i + rand(65535)))

  # FIXME We need to clear out @@nonce_count every once in a
  # great while, but I'm uncertain when the spec allows this.

  # FIXME only works for POST
  def self.gen_auth_header(uri, auth_header, user, password, is_IIS = false)
    auth_header =~ /^(\w+) (.*)/
    
    params = {}
    $2.gsub(/(\w+)=("[^"]*"|[^,]*)/) {
      params[$1] = $2.gsub(/^"/, '').gsub(/"$/, '')
    }
    
    @@nonce_count[params['nonce']] += 1
    
    a_1 = "#{user}:#{params['realm']}:#{password}"
    a_2 = "POST:#{uri.path}"
    request_digest = ''
    request_digest << Digest::MD5.hexdigest(a_1)
    request_digest << ':' << params['nonce']
    request_digest << ':' << ('%08x' % @@nonce_count[params['nonce']])
    request_digest << ':' << CNONCE
    request_digest << ':' << params['qop']
    request_digest << ':' << Digest::MD5.hexdigest(a_2)
    
    header = ''
    header << "Digest username=\"#{user}\", "
    if is_IIS then
      header << "qop=\"#{params['qop']}\", "
    else
      header << "qop=#{params['qop']}, "
    end
    header << "uri=\"#{uri.path}\", "
    header << %w{ algorithm opaque nonce realm }.map { |field|
      next unless params[field]
      "#{field}=\"#{params[field]}\""
    }.compact.join(', ')
    
    header << "nc=#{'%08x' % @@nonce_count[params['nonce']]}, "
    header << "cnonce=\"#{CNONCE}\", "
    header << "response=\"#{Digest::MD5.hexdigest(request_digest)}\""
    
    return header
  end
end
end
