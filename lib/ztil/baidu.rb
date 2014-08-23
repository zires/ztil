require 'rest-client'
require 'json'

# 百度的地理位置API | http://developer.baidu.com/map/index.php?title=webapi/guide/webservice-geocoding
module Ztil
  module Baidu

    BAIDU_AK  = 'A0f00186ba072b824d88d6300c9f7f86'
    BAIDU_URL = 'http://api.map.baidu.com'

    class << self

      def geocoder(address, options = {})
        r = JSON.parse RestClient.get("#{BAIDU_URL}/geocoder/v2/", { params: {address: address, output: :json, ak: BAIDU_AK, city: options[:city]} })
        JSON.pretty_generate(r)
      end

      def coordcoder(location, options = {})
        r = JSON.parse RestClient.get("#{BAIDU_URL}/geocoder/v2/", { params: {location: location, output: :json, ak: BAIDU_AK, coordtype: options[:coordtype]} })
        JSON.pretty_generate(r)
      end

    end

  end
end
