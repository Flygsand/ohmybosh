require 'bosh/session'

require 'net/http'
require 'uri'

module Bosh

  class Connection

    attr_accessor :endpoint, :session
    
    def initialize(endpoint)
      @endpoint = URI.parse(endpoint)
    end

    def connect(jid, password)
      @session = Bosh::Session.new(self, jid, password)
      @session.start
    end

    def post(data)
      http.post(@endpoint.path, data)
    end

    private
    
    def http
      @http ||= Net::HTTP.new(@endpoint.host, @endpoint.port)
    end
      
  end

end
