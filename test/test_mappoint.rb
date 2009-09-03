require 'test/unit'
require 'mappoint'
require 'mock_soap'

if ENV['cache_mode'] == 'store_new'
  MapPoint::Common.username = ENV['username']
  MapPoint::Common.password = ENV['password']
  MockSoap.cache_mode = :store_new
end

MockSoap.cache_dir = File.dirname(__FILE__) + '/data'

class TestMappoint < Test::Unit::TestCase

  def mock_soap
    @mock_soap ||= MockSoap.new(
                                :extra_namespaces =>{
                                  'xmlns' => "http://s.mappoint.net/mappoint-30/",
                                  'map' => 'http://s.mappoint.net/mappoint-30/'
                                })
    @mock_soap
  end

  def test_gets_token_okay
    mock_soap.for('GetClientToken').with_xpath('//map:ClientIPAddress/text()' => '10.1.0.100')
    mock_soap.for('GetClientToken').with_xpath('//map:ClientIPAddress/text()' => '127.0.0.1')
    localhost_tok = 'uS4O2Oo7zFQQDeR_Hadc-t7HQ9BS-fw1zHe65qEQas8w6pc-ivnlUpGUj2_-W5LBABmGq5Gl5RLzzAK-u0Ok_g2'
    private_tok = 'Ektq6xsB8sljkH2P857Wc-CUWShAgiXojM_pNOPfS24bLFY71Ir_FWb_jON2QynbQwqEPF8FirqYXAIJsRKYTw2'
    assert_equal localhost_tok, MapPoint::Common.get_client_token('127.0.0.1')
    assert_equal private_tok, MapPoint::Common.get_client_token('10.1.0.100')
  end

end
