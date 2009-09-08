require 'test/unit'
require 'mappoint'
require 'mock_soap'

if ENV['cache_mode'] == 'store_new'
  MapPoint.username = ENV['username']
  MapPoint.password = ENV['password']

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

  def test_gets_best_bounding_rectangle
    mock_soap.for('GetBestMapView').
      with_xpath('//map:Latitude/text()' => '-81', '//map:Longitude/text()' => '100')

    resp = {
      :southwest =>
      {
        :longitude => 98.205057962746153,
        :latitude => -81.289705052024544
      },
      :northeast =>
      {:longitude => 101.79494203725385, :latitude => -80.710294947975456}}
    assert_equal resp, MapPoint::Render.get_best_bounding_rectangle('-81', '100'), "as strings"
    assert_equal resp, MapPoint::Render.get_best_bounding_rectangle(-81, 100), "as numbers"
  end

  def test_okay_get_that_map_url
    mock_soap.for('GetMap').
      with_xpath('//map:Northeast/map:Latitude/text()' => '35.142',
                 '//map:Northeast/map:Longitude/text()' => '-116.254').
      with_xpath('//map:Southwest/map:Latitude/text()' => '33.142',
                 '//map:Southwest/map:Longitude/text()' => '-118.254').
      with_xpath('//map:Pushpins/map:Pushpin/map:IconDataSource/text()' =>
                 'Yellowpagesdotcom112881.112881').
      with_xpath('//map:Options/map:Zoom/text()' => '2')

    image_format = {
      :image_mimetype => 'image/gif',
      :height => 100,
      :width => 100
    }
    pushpins = [{
                  :icon_datasource => "Yellowpagesdotcom112881.112881",
                  :icon_name => 'yellowpages',
                  :latitude => 34.142,
                  :longitude => -118.254
                },
                {
                  :icon_datasource => "Yellowpagesdotcom112881.112881",
                  :icon_name => 'yellowpages',
                  :latitude => 34.142,
                  :longitude => -117.254
                }]
    box = {
      :northeast => {
        :latitude => 35.142, :longitude => -116.254
      },
      :southwest => {
        :latitude => 33.142, :longitude => -118.254
      }
    }
    map_options = {:zoom => 2}

    ret = MapPoint::Render.get_map(image_format,
                                       box,
                                       pushpins,
                                       map_options
                                       )
    expected = "http://cpmwsrender06.cp.prod.mappoint.net/render-30/getmap.aspx?key=EAEBDE77C151541B0F7B"

    assert_equal expected, ret[:url]
    assert_equal 34.144002889058321, ret[:by_height_width][:centerpoint][:latitude]
    assert_equal -117.254, ret[:by_height_width][:centerpoint][:longitude]

    br = ret[:by_bounding_rectangle]

    assert_equal 32.139690495379767, br[:southwest][:latitude]
    assert_equal -119.62124574631847, br[:southwest][:longitude]
    assert_equal 36.148315282736874, br[:northeast][:latitude]
    assert_equal -114.88675425368155, br[:northeast][:longitude]
  end
end
