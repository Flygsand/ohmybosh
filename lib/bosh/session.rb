require 'bosh/helpers/xml'
require 'bosh/helpers/string'
require 'bosh/helpers/xmpp'
require 'bosh/errors'
require 'sasl'

module Bosh

  class Session

    attr_reader :rid, :sid, :options
    
    def initialize(connection, jid, password, options = {})
      @connection, @password = connection, password
      
      @jid = split_jid(jid)
      raise ArgumentError, "Malformed JID '#{jid}'" unless @jid[:node] && @jid[:domain]

      @options = {}
      @options[:hold]   = options[:hold] || 1
      @options[:wait]   = options[:wait] || 60
      @options[:secure] = options[:secure] || true

      @features = {}
    end

    def start!
      [:initiate!, :authenticate!, :restart!, :bind_resource!].each do |step|
        send(step)
      end
    end

    def jid
      full_jid(@jid)
    end

    private
    
    include Bosh::Helpers::XML
    include Bosh::Helpers::String
    include Bosh::Helpers::XMPP
    
    def initiate!
      @rid = generate_id
      
      request = Nokogiri::XML::Builder.new do |b|
        b.body('content'      => 'text/xml; charset=utf-8',
               'rid'          => @rid,
               'from'         => bare_jid(@jid),
               'to'           => @jid[:domain],
               'hold'         => @options[:hold],
               'wait'         => @options[:wait],
               'secure'       => @options[:secure],
               'xml:lang'     => 'en',
               'xmpp:version' => '1.0',
               'xmlns'        => 'http://jabber.org/protocol/httpbind',
               'xmlns:xmpp'   => 'urn:xmpp:xbosh')
      end

      response = post(request)

      @options[:wait]           = to_i(response[:wait]) || @options[:wait]
      @options[:hold]           = to_i(response[:hold]) || @options[:hold]
      @options[:secure]         = to_bool(response[:secure]) || @options[:secure]
      @options[:inactivity]     = to_i(response[:inactivity])
      @options[:polling]        = to_i(response[:polling])
      @options[:accept]         = response[:accept]
      @options[:charsets]       = response[:charsets]

      @features[:auth] = response.xpath('//sasl:mechanism',
                                        'sasl' => 'urn:ietf:params:xml:ns:xmpp-sasl').map(&:text)
      
      @sid = response[:sid]

      self
    end

    def authenticate!
      raise ServerError, 'The server did not advertise support for any authentication mechanisms' if @features[:auth].empty?

      preferences = SASL::Preferences.new(:authzid          => bare_jid(@jid),
                                          :realm            => @jid[:domain],
                                          :digest_uri       => "xmpp/#{@jid[:domain]}",
                                          :username         => @jid[:node],
                                          :has_password?    => true,
                                          :password         => @password,
                                          :allow_plaintext? => true,
                                          :want_anonymous?  => false)

      self
    end
    
    def restart!
      request = Nokogiri::XML::Builder.new do |b|
        b.body('rid'          => @rid,
               'sid'          => @sid,
               'to'           => @jid[:domain],
               'xml:lang'     => 'en',
               'xmpp:restart' => true,
               'xmlns'        => 'http://jabber.org/protocol/httpbind',
               'xmlns:xmpp'   => 'urn:xmpp:xbosh')
      end

      response = post(request)

      self
    end

    def bind_resource!
      request = Nokogiri::XML::Builder.new do |b|
        b.iq('id'    => "bind_#{generate_id}",
             'type'  => 'set',
             'xmlns' => 'jabber:client') {
          b.bind('xmlns' => 'urn:ietf:params:xml:ns:xmpp-bind') {
            b.resource @jid[:resource]
          }
        }
      end

      response = post(wrap_in_body(request))
      @jid = split_jid(response.at_xpath('//bind:jid', 'bind' => 'urn:ietf:params:xml:ns:xmpp-bind').text)

      self
    end
    
    def wrap_in_body(request)
      Nokogiri::XML::Builder.new do |b|
        b.body('rid' => @rid,
               'sid' => @sid,
               'xmlns' => 'http://jabber.org/protocol/httpbind') {
          b.parent.add_child(root(request))
        }
      end
    end

    def generate_id
      rand(100000)
    end

    def post(obj)
      @rid += 1
      from_xml(@connection.post(to_xml(obj)))
    end
    
  end
  
end
