module MapPoint
  class Render < Service
    endpoint(:uri => 'http://renderv3.mappoint.net/Render-30/RenderService.asmx?WSDL',
             :version => 1)
    KM_TO_MILES = 0.621371192

    def get_best_bounding_rectangle(latitude, longitude)
      @response = mp_invoke('GetBestMapView') do |msg|
        msg.add 'map:locations' do |many_locs|
          many_locs.add 'map:Location' do |loc|
            loc.add 'map:LatLong' do |ll|
              ll.add 'map:Latitude', latitude
              ll.add 'map:Longitude', longitude
            end
          end
        end
        msg.add 'map:dataSourceName', 'MapPoint.NA'
      end

      by_br = native_doc.xpath('//xmlns:ByBoundingRectangle', ns).first
      parse_bounding_rectangle(by_br)
    end

    # FIXME This documentation is really crappily formatted and kinda lacking.
    # +:pushpins+ is an array of pushpins from their
    # start to finish. +:image_format+ is the +:height+, and +:width+
    # of the image desired in pixels and the +:image_mimetype+
    # (i.e. 'image/gif', 'image/jpeg', or
    # 'image/png'). +:bounding_box+ must be in the same format as the
    # returned data from +get_best_bounding_rectangle+.  Oh, and each
    # pushpin is a hash of options with it's own +:icon_name+, the
    # +:icon_datasource+ to find the icon in, and the +:latitude+ and
    # +:longitude+ for the pushpins. +:map_options+ are options for the
    # map specifically, including the +:pan_vertical+,
    # +:pan_horizontal+, +:zoom+ level, and +:render_type+ (which defaults
    # to 'ReturnUrl').
    # FIXME a whole host of other options to this endpoint are not implemented.
    def get_map(image_format, bounding_box, pushpins, map_options, parsed_route=nil)
      @response = mp_invoke('GetMap') do |msg|
        msg.set_attr 'xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance"
        msg.set_attr 'xmlns:xsd', 'http://www.w3.org/2001/XMLSchema/'
        msg.add 'map:specification' do |spec|
          spec.add 'map:DataSourceName', 'MapPoint.NA'
          if bounding_box
            spec.add 'map:Views' do |views|
              views.add 'map:MapView' do |bybr|
                bybr.set_attr 'xsi:type', 'map:ViewByBoundingRectangle'
                add_bounding_rectangle(bybr, bounding_box)
              end
            end
          end

          add_map_options(spec, map_options, image_format)
          add_push_pins(spec, pushpins)
          add_route(spec, parsed_route) if parsed_route
        end
      end

      parse_map_result(native_doc)
    end

    def get_simple_route_map(image_format, pushpins, map_options)
      route_xml = Route.calculate_simple_route_xml(pushpins)
      itinerary = parse_itinerary(route_xml)
      parsed_route = just_route(route_xml)
      itinerary.merge(get_map(image_format, nil, pushpins, map_options, parsed_route))
    end

    private
    def native_doc
      @response.document.native_element
    end
    
    def parse_bounding_rectangle(doc)
      ele = doc.xpath('./xmlns:BoundingRectangle', ns)
      parse_latlong(ele, 'Southwest').
        merge(parse_latlong(ele, 'Northeast'))
    end

    def parse_latlong(element, tagname)
      lat = long = nil
      cp = element.at(tagname, ns)
      cp.children.each do |c|
        case c.name
        when 'Latitude'
          lat = c.inner_text.to_f
        when 'Longitude'
          long = c.inner_text.to_f
        end
      end
      
      { tagname.downcase.to_sym =>
        { :latitude =>
            lat,
          :longitude =>
            long
        }
      }
    end

    def parse_map_result(doc)
      result = doc.xpath('//xmlns:GetMapResult[1]/xmlns:MapImage', ns)
      view = result.xpath('./xmlns:View', ns).first
      {
        :url => parse_url(result),
        :by_height_width => parse_by_height_width(view),
        :by_bounding_rectangle => parse_by_bounding_rectangle(view)
      }
    end
    
    def parse_url(doc)
      doc.xpath('./xmlns:Url', ns).inner_text
    end

    def parse_by_height_width(view)
      lat = long = nil
      cp = view.xpath('./xmlns:ByHeightWidth/xmlns:CenterPoint', ns)
      cp.first.children.each do |c|
        case c.name
        when 'Latitude'
          lat = c.inner_text.to_f
        when 'Longitude'
          long = c.inner_text.to_f
        end
      end
      {:centerpoint => {:latitude => lat, :longitude => long}}
    end

    def parse_by_bounding_rectangle(view)
      br = view.xpath('./xmlns:ByBoundingRectangle', ns)
      parse_bounding_rectangle(br)
    end

    def parse_itinerary(xml)
      return unless x = xml.xpath('//xmlns:Itinerary',ns)
      x = x[0].native_element
      {
        :total_driving_time => parse_driving_time(x),
        :total_distance => parse_distance(x),
        :itinerary => parse_segments(x)
      }
    end

    def parse_driving_time(x)
      x.xpath('./xmlns:DrivingTime', ns).inner_text.to_i
    end
    def parse_distance(x)
      x.xpath('./xmlns:Distance', ns).inner_text.to_f * KM_TO_MILES
    end

    def parse_segments(x)
      x.xpath('./xmlns:Segments/xmlns:Segment', ns).map{|s| parse_directions(s) }
    end

    def parse_directions(x)
      x.xpath('./xmlns:Directions/xmlns:Direction', ns).map do |d|
        dist = d.xpath('./xmlns:Distance[1]/text()', ns)[0].to_s.to_f * KM_TO_MILES
        {
          :duration => d.xpath('./xmlns:Duration[1]/text()', ns)[0].to_s.to_i,
          :distance => dist,
          :instruction => d.xpath('./xmlns:Instruction', ns).inner_text,
          :action => d.xpath('./xmlns:Action', ns).inner_text
        }
          
      end
    end
                       
    def add_bounding_rectangle(doc, bounding_box)
      doc.add 'map:BoundingRectangle' do |br|
        br.add 'map:Northeast' do |ne|
          ne.add 'map:Latitude', bounding_box[:northeast][:latitude]
          ne.add 'map:Longitude', bounding_box[:northeast][:longitude]
        end
        br.add 'map:Southwest' do |sw|
          sw.add 'map:Latitude', bounding_box[:southwest][:latitude]
                  sw.add 'map:Longitude', bounding_box[:southwest][:longitude]
        end
      end
    end

    def add_map_options(doc, map_options, image_format)
      doc.add 'map:Options' do |op|
        op.add 'map:Fontsize', 'Smaller'
        op.add 'map:ReturnType', map_options[:render_type] || 'ReturnUrl'
        
        op.add 'map:Format' do |fo|
          fo.add('map:MimeType', image_format[:image_mimetype] || 'image/png')
          fo.add('map:Height', image_format[:height] || 240)
          fo.add('map:Width', image_format[:width] || 296)
        end
        
        if mop = map_options
          op.add 'map:Zoom', mop[:zoom] || 1
          op.add('map:PanVertical', mop[:pan_vertical]) if mop[:pan_vertical]
          op.add('map:PanHorizontal', mop[:pan_horizontal]) if mop[:pan_horizontal]
        end
      end
    end

    def add_push_pins(doc, pushpins)
      doc.add 'map:Pushpins' do |pps|
            
        pushpins.each do |pin|
          pps.add('map:Pushpin') do |pp|
            pp.add 'map:IconDataSource', pin[:icon_datasource]
            pp.add 'map:IconName', pin[:icon_name]
            pp.add 'map:LatLong' do |ll|
              ll.add 'map:Latitude', pin[:latitude]
              ll.add 'map:Longitude', pin[:longitude]
            end
          end
        end
      end
    end

    def add_route(doc, parsed_route)
      doc.add 'Route' do |r|
        r.set_attr 'xmlns', ns['xmlns']
        parsed_route.children.each do |c|
          r.add c.name, c.children, :raw
        end
      end
    end

    def just_route(route_xml)
      elem = route_xml.
        xpath('//xmlns:CalculateSimpleRouteResult[1]', ns).
        first.native_element
      elem
    end
  end
end
