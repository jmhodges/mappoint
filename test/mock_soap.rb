# FIXME does not support multiple endpoints
class MockSoap
  attr_accessor :possible_responses, :extra_namespaces

  class << self
    attr_accessor :cache_mode
  end

  # Can be :read_only or :store_new
  self.cache_mode = :read_only
  
  def self.cache_dir
    raise "MockSoap.cache_dir has not been set." unless @cache_dir
    @cache_dir
  end
  
  def self.cache_dir=(new_dir)
    @cache_dir = File.expand_path(new_dir)
  end

  def self.path_is_writable?(file_path)
    cache_mode == :store_new && !File.exists?(file_path)
  end
  
  # Allowed options: extra_namespaces
  def initialize(opts)
    self.possible_responses = {}
    self.extra_namespaces = opts[:extra_namespaces]
    Handsoap::Http.drivers[:mock_soap] = CachedFileMockHttp.new(self)
    Handsoap.http_driver = :mock_soap
  end
  
  def for(soap_operation)
    possible_responses[soap_operation] ||= {}
    MockResponse.new(soap_operation, possible_responses[soap_operation])
  end

  def read(request)
    doc = parse_xml(request.body)

    desired_operation = parse_soap_operation(request.body)

    patterns_to_responses = possible_responses[desired_operation]

    matching_responses = patterns_to_responses.select do |k, response|
      response if k.all? do |patt, expectation|
        doc.xpath(patt, namespaces).to_raw == expectation
      end
    end
    
    check_number_of_responses_found(matching_responses)
    matching_responses[0][1].read(request)
  end

  def parse_soap_operation(body)
    parse_xml(body).xpath('//env:Body/*', namespaces).first.node_name
  end

  def parse_xml(string)
    Handsoap::XmlQueryFront.parse_string(string, Handsoap.xml_query_driver)
  end

  def namespaces
    {'env' => "http://schemas.xmlsoap.org/soap/envelope/"}.merge(extra_namespaces)
  end

  def check_number_of_responses_found(found_responses)
    if found_responses.empty?
      raise "None of the mocked out responses matched"
    end

    if found_responses.size > 1
      raise "Too many responses match this request"
    end
  end

  class MockResponse

    def initialize(soap_operation, patterns_to_responses)
      @soap_operation = soap_operation
      @patterns_to_responses = patterns_to_responses
      @patterns = {}
    end

    def with_xpath(patterns_to_expecations)
      @patterns_to_responses.delete(@patterns)
      @patterns.merge!(patterns_to_expecations)
      @patterns_to_responses[@patterns] = self
    end

    def read(request)
      if writable_to_cache?
        resp = call(request)
        store(resp) if resp.status == 200
      elsif !File.exists?(file_path)
        raise MissingCacheFile
      else
        resp = read_cached_file
      end
      resp
    end

    def file_path
      raise "no patterns set!" if @patterns.empty?
      arr = [@soap_operation]
      arr += @patterns.keys.sort.map do |k|
        k + @patterns[k]
      end
      File.join(MockSoap.cache_dir, Digest::MD5.hexdigest(arr.join("")))
    end

    private

    def call(request)
      Handsoap::Http::NetHttp.send_http_request(request)
    end

    def store(response)
      File.open(file_path, 'w'){|f| f.write(Marshal.dump(response)) }
    end

    def writable_to_cache?
      MockSoap.path_is_writable?(file_path)
    end

    def read_cached_file
      Marshal.load(File.open(file_path) {|f| f.read })
    end
  end
  
  class CachedFileMockHttp
    def initialize(mock_soap)
      @mock = mock_soap
    end
    
    def load!; true; end
    
    def send_http_request(request)
      @mock.read(request)
    end
  end
  
  class MissingCacheFile < StandardError;
    def initialize(msg=nil)
      msg ||= "The cached file does not exist for this request. "+
        "Run the tests in store_new mode to grab it."
      super(msg)
    end
  end
end
