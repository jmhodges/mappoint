module MapPoint
  class Render < Service
    endpoint(:uri => 'http://renderv3.mappoint.net/Render-30/RenderService.asmx?WSDL',
             :version => 1)
    def get_best_bounding_rectangle(latitude, longitude)
      response = mp_invoke('GetBestMapView') do |msg|
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

      parse_bounding_rectangle(response.document)
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
    # +:longitude+ for the pushpins. +:options+ are options for the
    # map specifically, including the +:pan_vertical+,
    # +:pan_horizontal+, +:zoom+ level and the +:image_mimetype+ with
    # the same available options as above.
    # FIXME a whole host of other options to this param are not implemented.
    def get_map(image_format, bounding_box, pushpins, map_options)
      response = mp_invoke('GetMap') do |msg|
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
      parse_url(response.document)
    end
    
    private
    def parse_bounding_rectangle(doc)
      ele = doc.xpath('//xmlns:BoundingRectangle', ns)[0].native_element
      parse_corner(ele, 'Southwest').
        merge(parse_corner(ele, 'Northeast'))
    end

    def parse_corner(element, corner_name)
      ele = element.at(corner_name, ns)
      { corner_name.downcase.to_sym =>
        { :latitude =>
          ele.at('Latitude/text()', ns).to_s.to_f,
          :longitude =>
          ele.at('Longitude/text()', ns).to_s.to_f
        }
      }
    end

    def parse_url(doc)
      xml_to_str(doc.xpath('//xmlns:Url/text()', ns))
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
