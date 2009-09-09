module MapPoint
  class Route < Service
    endpoint(:uri => 'http://routev3.mappoint.net/Route-30/RouteService.asmx?WSDL',
             :version => 1)

    # +points+ is an Array of Hashes containing a +:latitude+ and
    # +:longitude+. Sigh, this is only here for testing and to be used
    # by Render#get_simple_route_map
    def calculate_simple_route_xml(points, route_type="Quickest", source="MapPoint.NA")
      response = mp_invoke('CalculateSimpleRoute') do |msg|
        msg.add 'map:latLongs' do |lls|
          points.each do |po|
            lls.add 'map:LatLong' do |ll|
              ll.add 'map:Latitude', po[:latitude]
              ll.add 'map:Longitude', po[:longitude]
            end
          end
        end
        msg.add 'map:dataSourceName', source
        msg.add 'map:preference', route_type
      end
    end
  end
end
