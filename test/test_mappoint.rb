require 'test/unit'
require 'mappoint'
require 'mock_soap'

if ENV['cache_mode'] == 'store_new'
  MapPoint.username = ENV['username']
  MapPoint.password = ENV['password']

  MockSoap.cache_mode = :store_new
end

# Handsoap::Service.logger = File.open('foo.txt','w')

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

  def test_get_simple_route_map
    mock_soap.for('CalculateSimpleRoute').
      with_xpath('//map:latLongs/map:LatLong[1]/map:Latitude/text()' => '34.113033',
                 '//map:latLongs/map:LatLong[1]/map:Longitude/text()' => '-118.268506').
      with_xpath('//map:latLongs/map:LatLong[2]/map:Latitude/text()' => '34.11861',
                 '//map:latLongs/map:LatLong[2]/map:Longitude/text()' => '-118.29944')
    
    mock_soap.for('GetMap').
      with_xpath('//map:Pushpins/map:Pushpin/map:IconDataSource/text()' =>
                 'Yellowpagesdotcom112881.112881').
      with_xpath('//map:Options/map:Zoom/text()' => '2').
      with_xpath(
                 '//xmlns:Itinerary/xmlns:Segments/xmlns:Segment[1]/xmlns:Directions/xmlns:Direction[1]/xmlns:Instruction/text()' =>
                 'Depart Start on Riverside Dr (North-West)')
    image_format = {
      :image_mimetype => 'image/gif',
      :height => 100,
      :width => 100
    }
    pushpins = [{
                  :icon_datasource => "Yellowpagesdotcom112881.112881",
                  :icon_name => 'yellowpages',
                  :latitude => 34.113033,:longitude => -118.268506
                },
                {
                  :icon_datasource => "Yellowpagesdotcom112881.112881",
                  :icon_name => 'yellowpages',
                  :latitude => 34.11861, :longitude => -118.29944
                }]

    map_options = {:zoom => 2}

    ret = MapPoint::Render.get_simple_route_map(image_format,
                                                pushpins,
                                                map_options
                                                )
    assert_equal 530, ret[:total_driving_time]
    assert_in_delta 3.33054971374819, ret[:total_distance], 0.00001
    assert_not_nil ret[:itinerary]

    dir = ret[:itinerary][-2].last
    assert_in_delta 0.0683508353792101, dir[:distance], 0.00001
    assert_equal 12, dir[:duration]
    assert_equal 34.119260553270578, dir[:latitude]
    assert_equal -118.30026970244944, dir[:longitude]
    assert_equal 'BearLeft', dir[:action]
    assert_equal 'Bear LEFT (South-East) onto Local road(s)', dir[:instruction]
  end

  def test_okay_with_calculate_simple_route
    mock_soap.for('CalculateSimpleRoute').
      with_xpath('//map:latLongs/map:LatLong[1]/map:Latitude/text()' => '34.113033',
                 '//map:latLongs/map:LatLong[1]/map:Longitude/text()' => '-118.268506').
      with_xpath('//map:latLongs/map:LatLong[2]/map:Latitude/text()' => '34.11861',
                 '//map:latLongs/map:LatLong[2]/map:Longitude/text()' => '-118.29944')

    start = {:latitude => 34.113033,:longitude => -118.268506}
    finish = {:latitude => 34.11861, :longitude => -118.29944}
    points = [start, finish]
    parsed_xml = MapPoint::Route.calculate_simple_route_xml(points).native_element

    first_instruction = parsed_xml.xpath('//xmlns:Itinerary/xmlns:Segments/xmlns:Segment[1]/xmlns:Directions/xmlns:Direction[1]/xmlns:Instruction', {'xmlns' => "http://s.mappoint.net/mappoint-30/", 'map' => "http://s.mappoint.net/mappoint-30/"})
    assert_equal 'Depart Start on Riverside Dr (North-West)', first_instruction.inner_text
  end

  def test_finding_address
    mock_soap.for('FindAddress').
      with_xpath('//map:FormattedAddress/text()' => '611 N. Brand Blvd, Glendale, CA')
    resp = MapPoint::Find.find_address('611 N. Brand Blvd, Glendale, CA')
    assert_equal 1, resp[:number_found]
    assert_equal 1, resp[:results].size
    first = resp[:results].first
    assert_equal 34.155151, first[:latitude]
    assert_equal -118.255123, first[:longitude]
    assert_equal '611 N Brand Blvd', first[:address_line]
    assert_equal 'Glendale', first[:primary_city]
    assert_equal 'CA', first[:subdivision]
    assert_equal '91203-1221', first[:postal_code]
    assert_equal '611 N Brand Blvd, Glendale, CA 91203-1221', first[:formatted_address]
    assert_equal 0.95, first[:score]
    mock_soap.for('FindAddress').
      with_xpath('//map:FormattedAddress/text()' => '611 Brand Blvd, Glendale, CA')
    resp = MapPoint::Find.find_address('611 Brand Blvd, Glendale, CA')
    assert_equal 2, resp[:number_found]
    assert_equal 2, resp[:results].size
  end
end
