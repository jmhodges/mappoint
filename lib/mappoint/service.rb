module MapPoint
  class Service < Handsoap::Service
    MAPPOINT_URL = 'http://s.mappoint.net/mappoint-30/'
    class << self 
      attr_accessor :cached_digest_header
    end

    def self.parsed_uri
      @parsed_uri ||= URI.parse(uri)
      @parsed_uri
    end

    def username
      ::MapPoint.username
    end

    def password
      ::MapPoint.password
    end

    def on_create_document(doc)
      # The "map:" in the tags below are required and must have
      # this alias set in the document to work.
      doc.alias 'map', MAPPOINT_URL
    end

    # Handle HTTP digest authentication.
    # We assume we get a 401 back from the `send_http_request` we
    # explicitly call here, and need to handle the nonce nonsense that
    # is returned.
    def on_after_create_http_request(http_request)
      if self.class.cached_digest_header
        http_request.set_header('authorization', digest_auth_header_from_response)
      end
    end

    private
    # FIXME gross conditional. HttpError should have a ClientError
    # subclass for all 4xx status codes, etc.
    def mp_invoke(operation_name, &blk)
      begin
        mp_invoke_raw(operation_name, &blk)
      rescue Handsoap::HttpError => e
        raise e if e.response.status >= 500
        set_digest_header(e.response)
        mp_invoke_raw(operation_name, &blk)
      end
    end

    def mp_invoke_raw(operation_name, &blk)
      operation_url = MAPPOINT_URL + operation_name
      invoke('map:'+operation_name, :soap_action => operation_url, &blk)
    end
    
    def ns
      {'xmlns' => "http://s.mappoint.net/mappoint-30/"}
    end

    # FIXME Race condition
    def set_digest_header(http_response)
      # FIXME we need to make sure this header exists, and throw a new
      # error if it doesn't.
      self.class.cached_digest_header =
        http_response.headers['www-authenticate'][0]
    end
    
    def digest_auth_header_from_response
      DigestAuth.gen_auth_header(self.class.parsed_uri,
                                 self.class.cached_digest_header,
                                 self.class.username,
                                 self.class.password,
                                 true
                                 )
    end
  end
end
