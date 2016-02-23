# encoding: utf-8

require 'gooddata'

module GoodData::Bricks
  class SegmentSynchronizationBrick < GoodData::Bricks::Brick
    def version
      '0.0.1'
    end

    def call(params)
      # Connect to GD
      client = params['GDC_GD_CLIENT'] || fail('client needs to be passed into a brick as "GDC_GD_CLIENT"')

      # Get domain name
      domain_name = params['organization'] || params['domain'] || fail('No "organization" or "domain" specified')

      # Lookup for domain by name
      domain = client.domain(domain_name)

      # Check if segment (names) were specified
      segment_names = params['segment'] || params['segments'] || params['segment_names'] || :all

      segment_names = segment_names.split(', ') if segment_names.is_a?(String)
      segment_names = [segment_names] if segment_names.is_a?(Symbol)

      # Get segments
      segments = segment_names.map do |segment_name|
        domain.segments(segment_name)
      end

      # Flatten nested arrays
      segments.flatten!

      # Run synchronization
      res = segments.map do |segment|
        segment.synchronize_clients
      end

      res
    end
  end
end
