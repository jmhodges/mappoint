module MapPoint
  class Render < Service
    endpoint(:uri => 'http://renderv3.mappoint.net/Render-30/RenderService.asmx?WSDL',
             :version => 1)
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
    # +opts+ can include +:image_format+, +:pushpins+, and
    # +:bounding_box+. +:pushpins+ is an array of pushpins from their
    # start to finish. +:image_format+ is the +:height+, and +:width+
    # of the image desired in pixels and the +:image_mimetype+
    # (i.e. 'image/gif', 'image/jpeg', or
    # 'image/png'). +:bounding_box+ must be in the same format as the
    # returned data from +get_best_bounding_rectangle+.  Oh, and each
    # pushpin is a hash of options with it's own +:icon_name+, the
    # +:icon_datasource+ to find the icon in, and the +:latitude+ and
    # +:longitude+ for the pushpins. +:map_options+ are options for the
    # map specifically, including the +:pan_vertical+,
    # +:pan_horizontal+, +:zoom+ level, +:render_type+ (which defaults
    # to 'ReturnUrl') and the +:image_mimetype+ with
    # the same available options as above.
    # FIXME a whole host of other options to this param are not implemented.
    def get_map(image_format, bounding_box, pushpins, map_options)
      @response = mp_invoke('GetMap') do |msg|
        msg.set_attr 'xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance"
        msg.set_attr 'xmlns:xsd', 'http://www.w3.org/2001/XMLSchema/'
        msg.add 'map:specification' do |spec|
          spec.add 'map:DataSourceName', 'MapPoint.NA'
          spec.add 'map:Views' do |views|
            views.add 'map:MapView' do |bybr|
              bybr.set_attr 'xsi:type', 'map:ViewByBoundingRectangle'
              add_bounding_rectangle(bybr, bounding_box)
            end
          end

          add_map_options(spec, map_options, image_format)
          add_push_pins(spec, pushpins)
        end
      end
      parse_map_result(native_doc)
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
      cp = view.xpath('.//xmlns:ByHeightWidth/xmlns:CenterPoint', ns)
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
  end
end
