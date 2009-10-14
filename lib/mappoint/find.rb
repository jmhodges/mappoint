module MapPoint
  class Find < Service
    endpoint(:uri => 'http://findv3.mappoint.net/Find-30/FindService.asmx?WSDL',
             :version => 1)

    def find_address(address)
      resp = mp_invoke('FindAddress') do |msg|
        msg.add 'map:specification' do |spec|
          spec.add('map:DataSourceName', 'MapPoint.NA')
          spec.add('map:InputAddress') do |ia|
            ia.add('map:FormattedAddress', address)
          end
        end
      end
      parse_address_result(resp)
    end

    def parse_address_result(xml)
      res = xml.xpath('//xmlns:FindAddressResult', ns)[0].native_element
      {
        :number_found => res.xpath('./xmlns:NumberFound', ns).inner_text.to_i,
        :results => parse_locations(res.xpath('./xmlns:Results/xmlns:FindResult', ns))
      }
    end

    def parse_locations(xml)
      xml.xpath('./xmlns:FoundLocation', ns).map do |fl|
        parse_location(fl)
      end
    end

    def parse_location(xml)
      parse_latlong(xml).merge(parse_address(xml.at('Address', ns)))
    end

    def parse_address(xml)
      {
        :address_line => xml.at('AddressLine', ns).inner_text,
        :primary_city => xml.at('PrimaryCity', ns).inner_text,
        :secondary_city => xml.at('SecondaryCity', ns).inner_text,
        :subdivision => xml.at('Subdivision', ns).inner_text,
        :postal_code => xml.at('PostalCode', ns).inner_text,
        :formatted_address => xml.at('FormattedAddress', ns).inner_text
      }
    end
    
    def parse_latlong(element)
      cp = element.at('LatLong', ns)
      lat = long = nil
      cp.children.each do |c|
        case c.name
        when 'Latitude'
          lat = c.inner_text.to_f
        when 'Longitude'
          long = c.inner_text.to_f
        end
      end
      {:latitude => lat, :longitude => long}
    end
  end
end
