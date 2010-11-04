require 'spec_helper'

describe Bosh::Session do

  include Bosh::SpecHelper

  before do
    @connection = Bosh::Connection.new('http://example.com:5280/bosh')
    @session = Bosh::Session.new(@connection, 'user@example.com/httpclient', 'password')
    @session.stub(:generate_id).and_return(42)
    @session.instance_eval { @rid = 42 }
  end

  describe '#start!' do
    before do
      @session.stub!(:initiate!)
      @session.stub!(:authenticate!)
      @session.stub!(:restart!)
      @session.stub!(:bind_resource!)
    end
    
    it 'carries out each of the session startup steps in order' do
      [:initiate!, :authenticate!, :restart!, :bind_resource!].each do |step|
        @session.should_receive(step).ordered
      end
      
      @session.start!
    end
  end

  describe '#initiate!' do

    before do
      @request = Nokogiri::XML::Builder.new do |b|
        b.body('content'      => 'text/xml; charset=utf-8',
               'rid'          => 42,
               'from'         => 'user@example.com',
               'to'           => 'example.com',
               'hold'         => @session.options[:hold],
               'wait'         => @session.options[:wait],
               'secure'       => @session.options[:secure],
               'xml:lang'     => 'en',
               'xmpp:version' => '1.0',
               'xmlns'        => 'http://jabber.org/protocol/httpbind',
               'xmlns:xmpp'   => 'urn:xmpp:xbosh')
      end

      @response = Nokogiri::XML::Builder.new do |b|
        b.body('wait'              => 60,
               'inactivity'        => 30,
               'polling'           => 5,
               'hold'              => 1,
               'from'              => 'example.com',
               'accept'            => 'deflate,gzip',
               'sid'               => 'SomeSID',
               'secure'            => true,
               'charsets'          => 'ISO_8859-1 ISO-2022-JP',
               'xmpp:restartlogic' => true,
               'xmpp:version'      => '1.0',
               'authid'            => 'ServerStreamID',
               'xmlns'             => 'http://jabber.org/protocol/httpbind',
               'xmlns:xmpp'        => 'urn:xmpp:xbosh',
               'xmlns:stream'      => 'http://etherx.jabber.org/streams') {

          b['stream'].features {
            b.mechanisms('xmlns' => 'urn:ietf:params:xml:ns:xmpp-sasl') {
              b.mechanism 'MD5-DIGEST'
              b.mechanism 'PLAIN'
            }
          }
        }
      end          
    end

    it 'sends the appropriate XML' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { initiate! }
    end

    it 'adjusts session options based on values returned from connection manager' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { initiate! }

      @session.options[:wait].should        == 60
      @session.options[:inactivity].should  == 30
      @session.options[:polling].should     == 5
      @session.options[:hold].should        == 1
      @session.options[:accept].should      == 'deflate,gzip'
      @session.options[:secure].should      == true
      @session.options[:charsets].should    == 'ISO_8859-1 ISO-2022-JP'
      
    end

    it 'sets the supported authentication mechanisms' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { initiate! }

      @session.instance_eval { @features[:auth] }.should == ['MD5-DIGEST', 'PLAIN']
    end

    it 'sets the SID' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { initiate! }

      @session.sid.should == 'SomeSID'
    end
  end

=begin
  describe '#authenticate!' do

    context 'SASL PLAIN' do
      before do
        @session.instance_eval do
          @server = {
            :features => {
              :auth => ['PLAIN']
            }
          }
        end

        @request = Nokogiri::XML::Builder.new do |b|
          b.body('rid'   => 42,
                 'sid'   => 'SomeSID',
                 'xmlns' => 'http://jabber.org/protocol/httpbind') {
            
            b.auth('xmlns' => 'urn:ietf:params:xml:ns:xmpp-sasl',
                   'mechanism' => 'PLAIN')
            
          }
        end

        @response = Nokogiri::XML::Builder.new do |b|
          b.body('xmlns' => 'http://jabber.org/protocol/httpbind') {
            b.success('xmlns' => 'urn:ietf:params:xml:ns:xmpp-sasl')
          }
        end

        @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      end
      
      it 'sends the appropriate XML' do
        @session.instance_eval { authenticate! }
      end
    end
  end
=end

  describe '#restart!' do
    before do
      @request = Nokogiri::XML::Builder.new do |b|
        b.body('rid'          => 42,
               'sid'          => 'SomeSID',
               'to'           => 'example.com',
               'xml:lang'     => 'en',
               'xmpp:restart' => true,
               'xmlns'        => 'http://jabber.org/protocol/httpbind',
               'xmlns:xmpp'   => 'urn:xmpp:xbosh')
      end

      @response = Nokogiri::XML::Builder.new do |b|
        b.body('xmlns'             => 'http://jabber.org/protocol/httpbind',
               'xmlns:stream'      => 'http://etherx.jabber.org/streams') {

          b['stream'].features {
            b.bind('xmlns' => 'urn:ietf:params:xml:ns:xmpp-bind')
          }
        }
      end

      @session.instance_eval { @sid = 'SomeSID' }
    end
    
    it 'sends the appropriate XML' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { restart! }
    end
  end

  describe '#bind_resource!' do
    before do
      @request = Nokogiri::XML::Builder.new do |b|
        b.body('rid' => 42,
               'sid' => 'SomeSID',
               'xmlns' => 'http://jabber.org/protocol/httpbind') {

          b.iq('id' => 'bind_42',
               'type' => 'set',
               'xmlns' => 'jabber:client') {
            b.bind('xmlns' => 'urn:ietf:params:xml:ns:xmpp-bind') {
              b.resource 'httpclient'
            }
          }
          
        }
      end

      @response = Nokogiri::XML::Builder.new do |b|
        b.body('rid' => 42,
               'sid' => 'SomeSID',
               'xmlns' => 'http://jabber.org/protocol/httpbind') {

          b.iq('id' => 'bind_42',
               'type' => 'result',
               'xmlns' => 'jabber:client') {
            b.bind('xmlns' => 'urn:ietf:params:xml:ns:xmpp-bind') {
              b.jid 'user@example.com/bosh'
            }
          }
          
        }

        @session.instance_eval { @sid = 'SomeSID' }
        @session.instance_eval { @resource = '' }
      end
    end
    
    it 'sends the appropriate XML' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { bind_resource! }
    end

    it 'sets the JID returned by the server' do
      @connection.should_receive(:post).with(to_xml(@request)).and_return(to_xml(@response))
      @session.instance_eval { bind_resource! }

      @session.instance_eval { @jid }.should == { :node => 'user', :domain => 'example.com', :resource => 'bosh' }
    end
  end

  describe '#post' do
    before do
      @connection.stub!(:post).and_return('<body />')
    end
    
    it 'increments the RID by one' do
      @session.instance_eval do
        request = Nokogiri::XML('<body />')
        post(request)
      end
      @session.instance_eval { @rid }.should == 43
    end
  end
  
end
